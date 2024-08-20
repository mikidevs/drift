import gleam/int
import gleam/list
import gleam/string
import gleam/string_builder.{append}
import simplifile

pub fn main() {
  let pdf =
    new()
    |> page([page_a4()], [
      text([font_helvetica(), font_12()], "Hello pdf!", #(100, 700)),
    ])
    |> page([], [text([], "Goodbye", #(200, 300))])

  let filepath = "./priv/test.pdf"
  let assert Ok(_) = simplifile.delete(filepath)
  let assert Ok(_) = render(pdf) |> simplifile.write(to: filepath)
}

type PageSize {
  A4
}

type Font {
  Helvetica
}

type TextOption {
  TextFont(font: Font)
  TextFontSize(points: Int)
  TextAngle(degrees: Int)
  TextAlign(align: String)
  // left, right, justify etc
}

type PageOption {
  PageFont(font: Font)
  PageSize(size: PageSize)
}

type Element {
  TextElement(text: String, position: #(Int, Int), options: List(TextOption))
}

type Page {
  Page(content: List(Element), options: List(PageOption))
}

type PDF {
  PDF(pages: List(Page))
}

fn page_a4() {
  PageSize(A4)
}

fn font_helvetica() {
  TextFont(Helvetica)
}

fn font_12() {
  TextFontSize(12)
}

fn new() -> PDF {
  PDF([])
}

fn page(pdf: PDF, config: List(PageOption), elements: List(Element)) -> PDF {
  let page = Page(elements, config)
  PDF([page, ..pdf.pages])
}

fn text(
  config: List(TextOption),
  text: String,
  position: #(Int, Int),
) -> Element {
  TextElement(text, position, config)
}

fn render(pdf: PDF) -> String {
  let header = "%PDF-1.7\n"
  let text = "test"
  // Content Stream operators - BT: Begin text object; Tf: set font and size; Td: move text position; Tj: show text; ET: end text object
  let content_stream = "BT /F1 12 Tf 100 700 Td (" <> text <> ") Tj ET"
  let stream_length = content_stream |> string.length |> int.to_string

  // Any object may be marked indirect to by giving it an integer object identifier and a generation number, which is 0 for new pdfs
  // the object is bracketed by obj/endobj
  // <<>> marks a dictionary where /Name is a name object followed by a value

  // The page tree is used for optimisation and does not reflect the actual logical structure, it should idealy be a balanced tree

  // /Pages is an indirect reference to the tree node that is the root of the document's page tree
  // 2 0 R is an indirect reference to the object identified by 2 0 (which is the pages dict)

  // /Type /Pages is a page tree node, it has an indirect reference to the parent unless it is the root
  // /Kids is an array of indirect references to the immediate children
  // /Count is the number of leaf nodes (page objects or other page tree nodes)

  // /Type /Page is a page object and specifies the attributes of a single page of the document
  // /Parent is the immediate parent of the page
  // /Resources, any resources required by the page, empty if no resourcces are needed
  // /MediaBox is a rectangle in default user space units that define page boundaries
  let objects = [
    "1 0 obj\n<< /Type /Catelog /Pages 2 0 R >>\nendobj\n",
    "2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n",
    "3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R /Resources << /Font << /F1 5 0 R>> >> >>\nendobj\n",
    "4 0 obj\n<< /Length "
      <> stream_length
      <> " >>\nstream\n"
      <> content_stream
      <> "\nendstream\nendobj\n",
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
}
