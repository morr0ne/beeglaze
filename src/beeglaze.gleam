import gleam/bool
import gleam/dynamic/decode
import gleam/int
import gleam/io
import gleam/result
import gleam/string

const str = "4:spam"

const empty_str = "0:"

const int = "i2423e"

const neg_int = "i-412e"

const list = "l4:spam4:eggse"

const empty_list = "le"

const dict = "d3:cow3:moo4:spam4:eggse"

pub fn main() {
  str |> decode_string |> echo
  empty_str |> decode_string |> echo
}

pub type DecodeError {
  UnexpectedEndOfInput
  InvalidFormat
  InvalidLength
}

pub fn decode(source: String) -> Nil {
  case string.first(source) {
    Ok(char) -> Nil
    Error(Nil) -> Nil
  }
}

pub fn decode_int() -> Nil {
  todo
}

pub fn decode_string(source: String) -> Result(#(String, String), DecodeError) {
  use #(len, rest) <- result.try(
    source
    |> string.split_once(":")
    |> result.map_error(fn(_) { InvalidFormat }),
  )

  use len <- result.try(
    len
    |> int.parse
    |> result.map_error(fn(_) { InvalidLength }),
  )

  use <- bool.guard(rest |> string.length < len, Error(UnexpectedEndOfInput))

  Ok(#(
    string.slice(from: rest, at_index: 0, length: len),
    string.slice(from: rest, at_index: len, length: string.length(rest) - len),
  ))
}
