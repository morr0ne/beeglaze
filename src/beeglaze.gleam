import gleam/bit_array
import gleam/bool
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import gleamy/map as ordered_map

const str = <<"4:spam":utf8>>

const empty_str = <<"0:":utf8>>

const int = <<"i2423e":utf8>>

const neg_int = <<"i-412e":utf8>>

const list = <<"l4:spam4:eggse":utf8>>

const empty_list = <<"le":utf8>>

const dict = <<"d3:cow3:moo4:spam4:eggse":utf8>>

const ex = [str, empty_str, int, neg_int, list, empty_list, dict]

pub fn main() {
  ex |> list.each(fn(src) { src |> decode |> echo })
}

pub type DecodeError {
  UnexpectedEndOfInput
  InvalidFormat
  InvalidLength
}

pub type BencodeValue {
  BString(BitArray)
  BInt(Int)
  BList(List(BencodeValue))
  BDict(ordered_map.Map(BitArray, BencodeValue))
}

pub fn to_dynamic(value: BencodeValue) -> Dynamic {
  case value {
    BDict(dict) ->
      dict
      |> ordered_map.to_list
      |> list.map(fn(entry) {
        let #(key, value) = entry
        #(key |> dynamic.bit_array, value |> to_dynamic)
      })
      |> dynamic.properties
    BInt(int) -> int |> dynamic.int
    BList(list) -> list |> list.map(to_dynamic) |> dynamic.array
    BString(array) -> array |> dynamic.bit_array
  }
}

pub fn decode(
  source: BitArray,
) -> Result(#(BencodeValue, BitArray), DecodeError) {
  case source {
    <<"0":utf8, _:bytes>>
    | <<"1":utf8, _:bytes>>
    | <<"2":utf8, _:bytes>>
    | <<"3":utf8, _:bytes>>
    | <<"4":utf8, _:bytes>>
    | <<"5":utf8, _:bytes>>
    | <<"6":utf8, _:bytes>>
    | <<"7":utf8, _:bytes>>
    | <<"8":utf8, _:bytes>>
    | <<"9":utf8, _:bytes>> -> decode_string(source)
    <<"i":utf8, rest:bytes>> -> decode_int(rest, False)
    <<"i-":utf8, rest:bytes>> -> decode_int(rest, True)
    <<"l":utf8, rest:bytes>> -> decode_list(rest)
    <<"d":utf8, rest:bytes>> -> decode_dict(rest)
    _ -> Error(InvalidFormat)
  }
}

fn decode_string(
  source: BitArray,
) -> Result(#(BencodeValue, BitArray), DecodeError) {
  case source |> ascii_to_num(0) {
    #(len, <<":", rest:bytes>>) -> {
      use <- bool.guard(
        rest |> bit_array.byte_size < len,
        Error(UnexpectedEndOfInput),
      )

      use value <- result.try(
        rest
        |> bit_array.slice(0, len)
        |> result.replace_error(InvalidLength),
      )

      use rest <- result.try(
        rest
        |> bit_array.slice(len, bit_array.byte_size(rest) - len)
        |> result.replace_error(InvalidLength),
      )

      Ok(#(BString(value), rest))
    }
    _ -> Error(InvalidFormat)
  }
}

fn ascii_to_num(source: BitArray, significand: Int) -> #(Int, BitArray) {
  case source {
    <<48 as num, rest:bytes>>
    | <<49 as num, rest:bytes>>
    | <<50 as num, rest:bytes>>
    | <<51 as num, rest:bytes>>
    | <<52 as num, rest:bytes>>
    | <<53 as num, rest:bytes>>
    | <<54 as num, rest:bytes>>
    | <<55 as num, rest:bytes>>
    | <<56 as num, rest:bytes>>
    | <<57 as num, rest:bytes>> ->
      ascii_to_num(rest, significand * 10 + num - 48)
    rest -> #(significand, rest)
  }
}

fn decode_int(
  source: BitArray,
  negative: Bool,
) -> Result(#(BencodeValue, BitArray), DecodeError) {
  todo
  // use <- bool.guard(
  //   source |> string.starts_with("i") |> bool.negate,
  //   Error(InvalidFormat),
  // )

  // let source = source |> string.drop_start(1)

  // use #(num, _) <- result.try(
  //   source
  //   |> string.split_once("e")
  //   |> result.map_error(fn(_) { InvalidFormat }),
  // )

  // // String can't be empty
  // use <- bool.guard(num |> string.is_empty, Error(InvalidFormat))

  // // Negative zero is not allowed
  // use <- bool.guard(num |> string.starts_with("-0"), Error(InvalidFormat))

  // // Leading zeros are not allowed
  // use <- bool.guard(
  //   num |> string.starts_with("0") && num |> string.length > 1,
  //   Error(InvalidFormat),
  // )

  // use num <- result.try(
  //   num
  //   |> int.parse
  //   |> result.map_error(fn(_) { InvalidFormat }),
  // )

  // Ok(BInteger(num))
}

fn decode_list(
  source: BitArray,
) -> Result(#(BencodeValue, BitArray), DecodeError) {
  todo
}

fn decode_dict(
  source: BitArray,
) -> Result(#(BencodeValue, BitArray), DecodeError) {
  todo
}
