import bencode.{
  type BencodeDict, type BencodeValue, type DecodeError, BDict, BInt, BList,
  BString,
}
import gleam/option.{type Option, None, Some}
import gleam/result
import gleamy/map as ordered_map
import simplifile

pub type MetaInfo {
  MetaInfo(announce: Option(BitArray), info: Info)
}

pub type Info {
  Info(name: BitArray, piece_length: Int, pieces: BitArray)
}

pub fn main() {
  let assert Ok(bits) = simplifile.read_bits("temp/bunny.torrent")
  let assert Ok(value) = bits |> bencode.decode

  value |> decode_meta_info |> echo
}

fn decode_meta_info(value: BencodeValue) -> Result(MetaInfo, DecodeError) {
  case value {
    BDict(pairs) -> {
      use #(announce, pairs) <- optional_field(
        <<"announce">>,
        pairs,
        get_string,
      )
      use #(info, _pairs) <- field(<<"info">>, pairs, get_dict)
      use info <- result.try(decode_info(info))

      Ok(MetaInfo(announce:, info:))
    }
    _ -> Error(bencode.InvalidFormat)
  }
}

fn decode_info(pairs: BencodeDict) -> Result(Info, DecodeError) {
  use #(name, pairs) <- field(<<"name">>, pairs, get_string)
  use #(piece_length, pairs) <- field(<<"piece length">>, pairs, get_int)
  use #(pieces, _pairs) <- field(<<"pieces">>, pairs, get_string)

  Ok(Info(name:, piece_length:, pieces:))
}

fn get_string(value: BencodeValue) -> Option(BitArray) {
  case value {
    BString(s) -> Some(s)
    _ -> None
  }
}

fn get_int(value: BencodeValue) -> Option(Int) {
  case value {
    BInt(i) -> Some(i)
    _ -> None
  }
}

fn get_list(value: BencodeValue) -> Option(List(BencodeValue)) {
  case value {
    BList(l) -> Some(l)
    _ -> None
  }
}

fn get_dict(value: BencodeValue) -> Option(BencodeDict) {
  case value {
    BDict(d) -> Some(d)
    _ -> None
  }
}

fn field(
  name: BitArray,
  pairs: BencodeDict,
  getter: fn(BencodeValue) -> Option(v),
  next: fn(#(v, BencodeDict)) -> Result(a, DecodeError),
) -> Result(a, DecodeError) {
  case pairs |> ordered_map.get(name) {
    Ok(value) -> {
      use value <- result.try(
        getter(value) |> option.to_result(bencode.MissingField),
      )

      next(#(value, pairs |> ordered_map.delete(name)))
    }
    Error(_) -> Error(bencode.MissingField)
  }
}

fn optional_field(
  name: BitArray,
  pairs: BencodeDict,
  getter: fn(BencodeValue) -> Option(v),
  next: fn(#(Option(v), BencodeDict)) -> Result(a, DecodeError),
) -> Result(a, DecodeError) {
  case pairs |> ordered_map.get(name) {
    Ok(value) -> {
      next(#(getter(value), pairs |> ordered_map.delete(name)))
    }
    Error(_) -> next(#(None, pairs))
  }
}
