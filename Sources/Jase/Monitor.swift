import AVFoundation
import Vision

/// 카메라 → 얼굴 자리와 눈 윤곽 → 거리·기울임·높이·깜빡임. 영상은 메모리에서만 보고 버린다.
/// "수치 보기"를 켠 동안에만 숫자를 ~/Library/Logs/Jase/session.csv 에 적는다 (기준값을 맞춰 보는 용도).
final class Monitor: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "jase.camera")
    private let model: Model

    // 아래는 모두 queue 위에서만 만짐
    private var fps: Double
    private var log: FileHandle?
    private var logStart = 0.0
    private var baseline: (width: Double, height: Double)?
    private var widths: [Double] = [], heights: [Double] = []
    private var calibrationStart: Double?
    private var recent: [Double] = []      // 최근 몇 초의 눈 비율 (중앙값 = 평소 뜬 눈)
    private var wasClosed = false
    private var lastAnalyzed = 0.0
    private let request = VNDetectFaceLandmarksRequest()
    private let finder = VNDetectFaceRectanglesRequest()
    private var faceBox: VNFaceObservation?   // 마지막으로 찾은 얼굴 자리
    private var lastFound = 0.0

    private let prepare = 2.0   // 기준을 재기 전에 자세를 잡을 시간
    private let measure = 3.0   // 재는 시간

    init(model: Model) {
        self.model = model
        fps = Settings.shared.power.fps
        baseline = Settings.shared.baseline
        super.init()
    }

    func start() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            guard granted else {
                DispatchQueue.main.async { self.model.cameraUnavailable() }
                return
            }
            self.queue.async { self.configure() }
        }
    }

    func setRate(_ fps: Double) { queue.async { self.fps = fps; self.recent = [] } }

    func recalibrate() {
        queue.async { self.baseline = nil; self.widths = []; self.heights = []; self.calibrationStart = nil }
    }

    func setLogging(_ on: Bool) {
        queue.async {
            self.log = nil
            guard on else { return }
            let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/Jase")
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let file = dir.appendingPathComponent("session.csv")
            FileManager.default.createFile(atPath: file.path, contents: Data("t,face,eyeGap,distance,eye,eyeOpen,closed,blink,rollDeg,drop\n".utf8))
            self.log = try? FileHandle(forWritingTo: file)
            self.log?.seekToEndOfFile()
            self.logStart = 0
        }
    }

    private func configure() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .unspecified) ?? AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            DispatchQueue.main.async { self.model.cameraUnavailable() }
            return
        }
        session.beginConfiguration()
        session.sessionPreset = .vga640x480
        if session.canAddInput(input) { session.addInput(input) }
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        if session.canAddOutput(output) { session.addOutput(output) }
        session.commitConfiguration()
        session.startRunning()
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // 카메라는 초당 30장쯤 주지만 정해 둔 만큼만 분석
        let stamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
        guard stamp - lastAnalyzed >= 1 / fps - 0.005 else { return }
        lastAnalyzed = stamp
        guard let pixels = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let size = CGSize(width: CVPixelBufferGetWidth(pixels), height: CVPixelBufferGetHeight(pixels))
        let handler = VNImageRequestHandler(cvPixelBuffer: pixels, orientation: .up)
        if logStart == 0 { logStart = stamp }
        let t = stamp - logStart

        // 얼굴 찾기가 가장 무거워서 0.5초에 한 번만 하고, 그 사이에는 찾아 둔 자리에서 눈 윤곽만 다시 잼
        if faceBox == nil || stamp - lastFound >= 0.5 {
            try? handler.perform([finder])
            faceBox = finder.results?.max(by: { $0.boundingBox.width < $1.boundingBox.width })   // 가장 큰 얼굴 = 앞에 앉은 사람
            lastFound = stamp
        }
        var eyes: (VNFaceLandmarkRegion2D, VNFaceLandmarkRegion2D)?
        if let box = faceBox {
            request.inputFaceObservations = [box]
            try? handler.perform([request])
            if let marks = request.results?.first?.landmarks, let left = marks.leftEye, let right = marks.rightEye { eyes = (left, right) }
        }
        guard let (left, right) = eyes else {
            faceBox = nil
            if baseline == nil {   // 기준을 재는 중에 얼굴이 사라지면 처음부터
                calibrationStart = nil; widths = []; heights = []
                DispatchQueue.main.async { self.model.calibrationLostFace() }
            }
            write(String(format: "%.3f,0,,,,,,,,\n", t))
            return
        }

        // 영상에서 왼쪽에 보이는 눈 → 오른쪽에 보이는 눈 (y는 위가 +)
        var a = center(left, size), b = center(right, size)
        if a.x > b.x { swap(&a, &b) }
        // 거리: 두 눈 사이 간격 ÷ 영상 폭 (가까울수록 커짐)
        let gap = Double(hypot(b.x - a.x, b.y - a.y) / size.width)
        // 기울임: 두 눈을 잇는 선의 각도. 거울처럼 보이게 화면 기준 시계 방향을 +로
        let roll = Double(atan2(b.y - a.y, b.x - a.x))
        let height = Double((a.y + b.y) / 2 / size.height)
        let eye = (openness(left, size) + openness(right, size)) / 2
        var sample = Sample(roll: roll, eye: eye)

        // 깜빡임: 눈 높이/폭 비가 평소 뜬 값(최근 5초의 중앙값)보다 확 내려갔다가 돌아오면 한 번.
        // 중앙값이라 깜빡이는 순간이나 한두 장 튀는 값에 끌려가지 않음
        recent.append(eye)
        if recent.count > Int(fps * 5) { recent.removeFirst(recent.count - Int(fps * 5)) }
        let open = recent.sorted()[recent.count / 2]
        let closed = eye < open * 0.62
        sample.blinked = wasClosed && !closed
        wasClosed = closed
        sample.eyeOpen = open

        if let baseline {
            sample.distance = gap / baseline.width
            // 내려앉음: 기준보다 눈이 얼마나 내려갔는지를 두 눈 사이 간격의 배수로
            sample.drop = (baseline.height - height) * Double(size.height) / (baseline.width * Double(size.width))
        } else {
            // 기준 자세: 자세를 잡을 시간을 준 뒤 몇 초 동안의 중앙값
            if calibrationStart == nil { calibrationStart = stamp }
            let elapsed = stamp - calibrationStart!
            if elapsed >= prepare { widths.append(gap); heights.append(height) }
            sample.progress = min(1, elapsed / (prepare + measure))
            sample.blinked = false
            if elapsed >= prepare + measure, !widths.isEmpty {
                let measured = (width: widths.sorted()[widths.count / 2], height: heights.sorted()[heights.count / 2])
                baseline = measured
                calibrationStart = nil; widths = []; heights = []
                DispatchQueue.main.async {
                    Settings.shared.baseline = measured
                    self.model.calibrated()
                }
                return
            }
        }
        write(String(format: "%.3f,1,%.4f,%.3f,%.4f,%.4f,%d,%d,%.1f,%.2f\n", t, gap, sample.distance, eye, open, closed ? 1 : 0, sample.blinked ? 1 : 0, roll * 180 / .pi, sample.drop))
        let result = sample
        DispatchQueue.main.async { self.model.frame(result) }
    }

    /// 눈 윤곽 점들의 높이 ÷ 폭 (감으면 작아짐)
    private func openness(_ region: VNFaceLandmarkRegion2D, _ size: CGSize) -> Double {
        let points = region.pointsInImage(imageSize: size)
        guard let minX = points.map(\.x).min(), let maxX = points.map(\.x).max(),
              let minY = points.map(\.y).min(), let maxY = points.map(\.y).max(), maxX > minX else { return 0 }
        return Double((maxY - minY) / (maxX - minX))
    }

    private func center(_ region: VNFaceLandmarkRegion2D, _ size: CGSize) -> CGPoint {
        let points = region.pointsInImage(imageSize: size)
        let count = CGFloat(max(points.count, 1))
        return CGPoint(x: points.map(\.x).reduce(0, +) / count, y: points.map(\.y).reduce(0, +) / count)
    }

    private func write(_ line: String) { log?.write(Data(line.utf8)) }
}
