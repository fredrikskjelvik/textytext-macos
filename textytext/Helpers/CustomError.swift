import Foundation

enum CustomError: String, Error {
    case FailedToConvertBlockDataToBlocks = "The content stored in field designated for text view blocks could not be decoded into blocks. Bad formatting."
}
