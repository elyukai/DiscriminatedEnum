import DiscriminatedEnum
import Foundation

@DiscriminatedEnum()
enum Test {
    case hello, reallyCamel
    case world(Int)
}

let decoder = JSONDecoder()
let json = """
{
    "tag": "World",
    "world": 1
}
"""

let result = try decoder.decode(Test.self, from: json.data(using: .utf8)!)

print("The value \(result) was produced by the code \"\(json)\"")
