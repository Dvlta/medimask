import UIKit

struct DetectionResult {
    let originalImage: UIImage
    let scrubbedImage: UIImage
    let regions: [RedactionRegion]
    let timings: ProcessingTimings
}
