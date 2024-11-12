import DiscriminatedEnum

let a = 17
let b = 25

@DiscriminatedEnum
enum Test {
    case hello, reallyCamel
    case world(Int)
}

//let (result, code) = #stringify(a + b)
//
//print("The value \(result) was produced by the code \"\(code)\"")
