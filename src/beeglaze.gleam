import bencode.{type BencodeValue, type DecodeError}
import simplifile

pub type MetaInfo {
  MetaInfo(announce: BitArray, info: Info)
}

pub type Info {
  Info(name: BitArray, piece_length: Int, pieces: BitArray)
}

pub fn main() {
  // let info_decoder = {
  //   use name <- decode.field("name", decode.bit_array)
  //   use piece_length <- decode.field("piece length", decode.int)
  //   use pieces <- decode.field("pieces", decode.bit_array)

  //   decode.success(Info(name:, piece_length:, pieces:))
  // }

  // let meta_info_decoder = {
  //   use announce <- decode.field("announce", decode.bit_array)
  //   use info <- decode.field("info", info_decoder)

  //   decode.success(MetaInfo(announce, info:))
  // }

  let assert Ok(bits) = simplifile.read_bits("temp/bunny.torrent")
  let assert Ok(value) = bits |> bencode.decode

  // value |> bencode.to_dynamic |> decode.run(meta_info_decoder) |> echo
  value |> decode_meta_info |> echo
}

fn decode_meta_info(value: BencodeValue) -> Result(MetaInfo, DecodeError) {
  todo
}
