---
name: document-conversion
description: Extract Markdown or text from PDF, DOCX, PPTX, XLSX, and common structured files with the tools built into agent-space. Use when an agent needs document contents for analysis rather than high-fidelity visual conversion.
---

# Document Conversion

Use the built-in tools for local, lightweight content extraction. The image
does not include an office suite, OCR engine, TeX distribution, or Pandoc.

## Convert to Markdown

MarkItDown supports PDF, DOCX, PPTX, XLSX, HTML, text, CSV, JSON, XML, ZIP, and
other lightweight input formats:

```bash
markitdown input.pdf -o output.md
markitdown input.docx > output.md
```

Its output is intended for LLM and text-analysis workflows. It is not a
high-fidelity document renderer. Treat files and URLs as inputs available with
the permissions and network access of the current process; validate untrusted
paths and URLs before conversion.

## Inspect PDFs directly

`poppler-utils` is installed for focused PDF operations. Prefer a narrow tool
when Markdown conversion is unnecessary:

```bash
pdfinfo input.pdf
pdftotext input.pdf output.txt
pdftoppm -png -f 1 -singlefile input.pdf preview
```

Scanned documents without an embedded text layer require an OCR tool installed
at runtime. Advanced format-to-format publishing can be added with Pandoc at
runtime when the task actually needs it.

For supported MarkItDown inputs and security considerations, read the
[Microsoft MarkItDown repository](https://github.com/microsoft/markitdown).
