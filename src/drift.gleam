import gleam/int
import gleam/io
import gleam/list
import gleam/string
import gleam/string_builder.{append}
import simplifile
import sprinkle.{format}

pub fn main() {
  let header = "%PDF-1.7\n"
  let text = "hello pdf!"
  let content_stream = "BT /F1 24 Tf 100 700 Td (" <> text <> ") Tj ET"

  let objects = [
    "1 0 obj\n<< /Type /Catelog /Pages 2 0 R >>\nendobj\n",
    "2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n",
    "3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R /Resources << >> >>\nendobj\n",
    format(
      "4 0 obj\n<< /Length {stream_length} >>\nstream\n{content_stream}\nendstream\nendobj\n",
      [
        #("stream_length", content_stream |> string.length |> int.to_string),
        #("content_stream", content_stream),
      ],
    ),
    "5 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj\n",
  ]

  let #(cross_reference_table, offset) =
    list.fold(
      objects,
      #(
        "xref\n0 "
          <> list.length(objects) |> int.to_string
          <> "\n0000000000 65535 f \n",
        string.byte_size(header),
      ),
      fn(tup, obj) {
        case tup, obj {
          #(str, bytes), obj -> {
            let ref_entry =
              str
              <> string.pad_left(int.to_string(bytes), to: 10, with: "0")
              <> " 00000 n \n"
            #(ref_entry, bytes + string.byte_size(obj))
          }
        }
      },
    )

  let trailer =
    "trailer\n<< /Size 6 /Root 1 0 R >>\nstartxref\n"
    <> int.to_string(offset)
    <> "\n%%EOF"

  let pdf =
    string_builder.from_string(header)
    |> string_builder.append_builder(list.fold(
      objects,
      string_builder.new(),
      append,
    ))
    |> append(cross_reference_table)
    |> append(trailer)
    |> string_builder.to_string

  let filepath = "./priv/test.pdf"
  let assert Ok(_) = pdf |> simplifile.write(to: filepath)
}
