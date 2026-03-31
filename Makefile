# Makefile: helpers to build artifacts (optional)
PDF: report.pdf

report.pdf: report.md
	pandoc report.md -o report.pdf --pdf-engine=xelatex

.PHONY: PDF
