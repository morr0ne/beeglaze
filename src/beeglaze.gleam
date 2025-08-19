import bencode.{
  type BencodeDict, type BencodeValue, type DecodeError, BDict, BInt, BList,
  BString,
}
import gleam/result
import gleamy/map as ordered_map
import simplifile

pub type MetaInfo {
  MetaInfo(announce: BitArray, info: Info)
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
      use #(announce, pairs) <- get_string(<<"announce">>, pairs)
      use #(info, _pairs) <- get_dict(<<"info">>, pairs)
      use info <- result.try(decode_info(info))

      Ok(MetaInfo(announce:, info:))
    }
    _ -> Error(bencode.InvalidFormat)
  }
}

fn decode_info(pairs: BencodeDict) -> Result(Info, DecodeError) {
  use #(name, pairs) <- get_string(<<"name">>, pairs)
  use #(piece_length, pairs) <- get_int(<<"piece length">>, pairs)
  use #(pieces, _pairs) <- get_string(<<"pieces">>, pairs)

  Ok(Info(name:, piece_length:, pieces:))
}

pub fn get_string(
  name: BitArray,
  pairs: BencodeDict,
  next: fn(#(BitArray, BencodeDict)) -> Result(a, DecodeError),
) -> Result(a, DecodeError) {
  use #(value, pairs) <- field(name, pairs)

  case value {
    BString(str) -> next(#(str, pairs))
    _ -> Error(bencode.InvalidType)
  }
}

pub fn get_int(
  name: BitArray,
  pairs: BencodeDict,
  next: fn(#(Int, BencodeDict)) -> Result(a, DecodeError),
) -> Result(a, DecodeError) {
  use #(value, pairs) <- field(name, pairs)

  case value {
    BInt(int) -> next(#(int, pairs))
    _ -> Error(bencode.InvalidType)
  }
}

pub fn get_list(
  name: BitArray,
  pairs: BencodeDict,
  next: fn(#(List(BencodeValue), BencodeDict)) -> Result(a, DecodeError),
) -> Result(a, DecodeError) {
  use #(value, pairs) <- field(name, pairs)

  case value {
    BList(list) -> next(#(list, pairs))
    _ -> Error(bencode.InvalidType)
  }
}

pub fn get_dict(
  name: BitArray,
  pairs: BencodeDict,
  next: fn(#(BencodeDict, BencodeDict)) -> Result(a, DecodeError),
) -> Result(a, DecodeError) {
  use #(value, pairs) <- field(name, pairs)

  case value {
    BDict(dict) -> next(#(dict, pairs))
    _ -> Error(bencode.InvalidType)
  }
}

fn field(
  name: BitArray,
  pairs: BencodeDict,
  next: fn(#(BencodeValue, BencodeDict)) -> Result(a, DecodeError),
) -> Result(a, DecodeError) {
  case pairs |> ordered_map.get(name) {
    Ok(value) -> {
      next(#(value, pairs |> ordered_map.delete(name)))
    }
    Error(_) -> Error(bencode.MissingField)
  }
}
