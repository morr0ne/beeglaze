import bencode.{
  type BencodeDict, type BencodeValue, type DecodeError, BDict, BInt, BList,
  BString,
}
import gleam/bit_array
import gleam/crypto.{Sha1, digest, hash_chunk, new_hasher}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleamy/map as ordered_map
import simplifile

pub type MetaInfo {
  MetaInfo(announce: Option(BitArray), info: Info)
}

pub type Info {
  Info(name: BitArray, piece_length: Int, pieces: BitArray, files: Files)
}

pub type Files {
  SingleFile(length: Int)
  MultipleFiles(files: BencodeValue)
}

pub fn main() {
  let assert Ok(bits) = simplifile.read_bits("temp/arch.torrent")
  let assert Ok(value) = bits |> bencode.decode

  let assert Ok(meta_info) = value |> decode_meta_info

  let hash =
    new_hasher(Sha1)
    |> hash_chunk(meta_info.info |> info_to_value |> bencode.encode)
    |> digest
    |> bit_array.base16_encode
    |> string.lowercase

  echo hash
}

fn info_to_value(info: Info) -> BencodeValue {
  let map =
    bencode.new_ordered_map()
    |> ordered_map.insert(<<"name">>, BString(info.name))
    |> ordered_map.insert(<<"piece length">>, BInt(info.piece_length))
    |> ordered_map.insert(<<"pieces">>, BString(info.pieces))

  case info.files {
    MultipleFiles(files:) -> map |> ordered_map.insert(<<"files">>, files)
    SingleFile(length:) -> map |> ordered_map.insert(<<"length">>, BInt(length))
  }
  |> BDict
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
  use #(pieces, pairs) <- field(<<"pieces">>, pairs, get_string)
  use #(length, pairs) <- optional_field(<<"length">>, pairs, get_int)

  case length {
    Some(length) -> {
      use <- deny_unknown_fields(pairs)

      Ok(Info(name:, piece_length:, pieces:, files: SingleFile(length:)))
    }

    None -> {
      use #(files, pairs) <- optional_field(<<"files">>, pairs, get_list)

      case files {
        None -> Error(bencode.MissingField)
        Some(files) -> {
          use <- deny_unknown_fields(pairs)

          Ok(Info(
            name:,
            piece_length:,
            pieces:,
            files: MultipleFiles(files: BList(files)),
          ))
        }
      }
    }
  }
}

fn deny_unknown_fields(
  pairs: BencodeDict,
  other: fn() -> Result(a, DecodeError),
) -> Result(a, DecodeError) {
  let fields = pairs |> ordered_map.to_list |> list.map(fn(pair) { pair.0 })

  case fields |> list.is_empty {
    False -> Error(bencode.UnknownFields(fields))
    True -> other()
  }
}

fn get_string(value: BencodeValue) -> Result(BitArray, DecodeError) {
  case value {
    BString(s) -> Ok(s)
    _ -> Error(value |> bencode.value_to_type |> bencode.UnexpectedType)
  }
}

fn get_int(value: BencodeValue) -> Result(Int, DecodeError) {
  case value {
    BInt(i) -> Ok(i)
    _ -> Error(value |> bencode.value_to_type |> bencode.UnexpectedType)
  }
}

fn get_list(value: BencodeValue) -> Result(List(BencodeValue), DecodeError) {
  case value {
    BList(l) -> Ok(l)
    _ -> Error(value |> bencode.value_to_type |> bencode.UnexpectedType)
  }
}

fn get_dict(value: BencodeValue) -> Result(BencodeDict, DecodeError) {
  case value {
    BDict(d) -> Ok(d)
    _ -> Error(value |> bencode.value_to_type |> bencode.UnexpectedType)
  }
}

fn field(
  name: BitArray,
  pairs: BencodeDict,
  getter: fn(BencodeValue) -> Result(v, DecodeError),
  next: fn(#(v, BencodeDict)) -> Result(a, DecodeError),
) -> Result(a, DecodeError) {
  case pairs |> ordered_map.get(name) {
    Ok(value) -> {
      use value <- result.try(getter(value))

      next(#(value, pairs |> ordered_map.delete(name)))
    }
    Error(_) -> Error(bencode.MissingField)
  }
}

fn optional_field(
  name: BitArray,
  pairs: BencodeDict,
  getter: fn(BencodeValue) -> Result(v, DecodeError),
  next: fn(#(Option(v), BencodeDict)) -> Result(a, DecodeError),
) -> Result(a, DecodeError) {
  case pairs |> ordered_map.get(name) {
    Ok(value) -> {
      next(#(
        getter(value) |> option.from_result,
        pairs |> ordered_map.delete(name),
      ))
    }
    Error(_) -> next(#(None, pairs))
  }
}
