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
import simplifile

pub type MetaInfo {
  MetaInfo(announce: BitArray, info: Info)
}

pub type Info {
  Info(name: BitArray, piece_length: Int, pieces: BitArray)
}

pub fn main() {
  let info_decoder = {
    use name <- decode.field("name", decode.bit_array)
    use piece_length <- decode.field("piece length", decode.int)
    use pieces <- decode.field("pieces", decode.bit_array)

    decode.success(Info(name:, piece_length:, pieces:))
  }

  let meta_info_decoder = {
    use announce <- decode.field("announce", decode.bit_array)
    use info <- decode.field("info", info_decoder)

    decode.success(MetaInfo(announce, info:))
  }

  let assert Ok(bits) = simplifile.read_bits("temp/bunny.torrent")
  let assert Ok(value) = bits |> decode

  value |> to_dynamic |> decode.run(meta_info_decoder) |> echo
}

pub type DecodeError {
  UnexpectedEndOfInput
  InvalidFormat
  InvalidLength
}

pub type OrderedMap(k, v) =
  ordered_map.Map(k, v)

pub fn new_ordered_map() -> OrderedMap(BitArray, BencodeValue) {
  ordered_map.new(bit_array.compare)
}

pub type BencodeValue {
  BString(BitArray)
  BInt(Int)
  BList(List(BencodeValue))
  BDict(OrderedMap(BitArray, BencodeValue))
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

pub fn encode(value: BencodeValue) -> BitArray {
  case value {
    BString(str) -> {
      let len = str |> bit_array.byte_size |> int.to_string
      <<len:utf8, ":", str:bits>>
    }
    BInt(i) -> <<"i", int.to_string(i):utf8, "e">>
    BList(values) -> {
      let encoded =
        values
        |> list.fold(<<>>, fn(acc, value) {
          acc |> bit_array.append(encode(value))
        })

      <<"l", encoded:bits, "e">>
    }
    BDict(pairs) -> {
      let encoded =
        pairs
        |> ordered_map.fold(<<>>, fn(acc, key, value) {
          acc
          |> bit_array.append(<<encode(BString(key)):bits, encode(value):bits>>)
        })

      <<"d", encoded:bits, "e">>
    }
  }
}

pub fn decode(source: BitArray) -> Result(BencodeValue, DecodeError) {
  case decode_value(source) {
    Ok(#(value, <<>>)) -> Ok(value)
    Ok(#(_, _)) -> Error(InvalidLength)
    Error(error) -> Error(error)
  }
}

fn decode_value(
  source: BitArray,
) -> Result(#(BencodeValue, BitArray), DecodeError) {
  case source {
    // --- String parsing ---
    //
    // Handle empty string special case
    <<"0:", rest:bytes>> -> Ok(#(BString(<<>>), rest))
    // Error out on leading zeros
    <<"0", _:bytes>> -> Error(InvalidFormat)
    // If we match any other number then we can assume it's the lenght of a string
    <<"1", _:bytes>>
    | <<"2", _:bytes>>
    | <<"3", _:bytes>>
    | <<"4", _:bytes>>
    | <<"5", _:bytes>>
    | <<"6", _:bytes>>
    | <<"7", _:bytes>>
    | <<"8", _:bytes>>
    | <<"9", _:bytes>> -> decode_string(source)

    // --- Number parsing ---
    //
    // We can just match on a 0
    <<"i0e", rest:bytes>> -> Ok(#(BInt(0), rest))
    // Empty numbers are not valid
    <<"ie", _:bytes>> -> Error(InvalidFormat)
    // Negative zero is not allowed
    <<"i-0e", _:bytes>> -> Error(InvalidFormat)
    // We already checked for zero itself and negative zero
    // Any other zero is a leading zero which is not allowed
    <<"i0", _:bytes>> | <<"i-0", _:bytes>> -> Error(InvalidFormat)
    // Check for negative sign first
    <<"i-", rest:bytes>> -> decode_int(rest, True)
    <<"i", rest:bytes>> -> decode_int(rest, False)

    // --- List Parsing ---
    //
    // Handle an empty list by just matching
    <<"le", rest:bytes>> -> Ok(#(BList([]), rest))
    <<"l", rest:bytes>> -> decode_list(rest, [])

    // --- Dict Parsing ---
    //
    // Handle an empty dict by just matching
    <<"de", rest:bytes>> -> Ok(#(BDict(new_ordered_map()), rest))
    <<"d", rest:bytes>> -> decode_dict(rest, new_ordered_map())
    _ -> Error(InvalidFormat)
  }
}

fn decode_string(
  source: BitArray,
) -> Result(#(BencodeValue, BitArray), DecodeError) {
  let #(len, rest) = source |> ascii_to_num(0)

  case rest {
    <<":", value:bytes-size(len), rest:bytes>> -> Ok(#(BString(value), rest))
    _ -> Error(InvalidFormat)
  }
}

fn decode_int(
  source: BitArray,
  negative: Bool,
) -> Result(#(BencodeValue, BitArray), DecodeError) {
  let #(num, rest) = source |> ascii_to_num(0)

  case rest {
    <<"e", rest:bytes>> -> {
      case negative {
        False -> Ok(#(BInt(num), rest))
        True -> Ok(#(BInt(-num), rest))
      }
    }
    _ -> Error(InvalidFormat)
  }
}

fn decode_list(
  source: BitArray,
  acc: List(BencodeValue),
) -> Result(#(BencodeValue, BitArray), DecodeError) {
  case source {
    <<"e", rest:bytes>> -> Ok(#(BList(acc |> list.reverse), rest))
    _ ->
      case decode_value(source) {
        Error(error) -> Error(error)
        Ok(#(value, rest)) -> decode_list(rest, [value, ..acc])
      }
  }
}

fn decode_dict(
  source: BitArray,
  acc: OrderedMap(BitArray, BencodeValue),
) -> Result(#(BencodeValue, BitArray), DecodeError) {
  case source {
    <<"e", rest:bytes>> -> Ok(#(BDict(acc), rest))
    _ -> {
      case decode_value(source) {
        Ok(#(BString(str), rest)) -> {
          case decode_value(rest) {
            Ok(#(value, rest)) ->
              decode_dict(rest, acc |> ordered_map.insert(str, value))
            Error(error) -> Error(error)
          }
        }
        Ok(_) -> Error(InvalidFormat)
        Error(error) -> Error(error)
      }
    }
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
