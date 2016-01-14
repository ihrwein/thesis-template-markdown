# constants for defining the author, title, etc.
FILENAME = thesis
TITLE = Rust language bindings in syslog-ng
AUTHOR = Benke Tibor
ADVISOR = Budai László
UNIVERSITY = Budapesti Műszaki és Gazdaságtudományi Egyetem
DEPARTMENT = Távközlési és Médiainformatikai Tanszék
RESEARCH_GROUP = 
THESIS_TYPE = Szakmai gyakorlat beszámoló
DOCUMENT_LANG = english
SOURCE_FILES = chapter1.md chapter2.md chapter3.md chapter4.md summary.md

# variables for the PDF/HTML compiler
ARGS = \
	$(SOURCE_FILES) \
	--from=markdown \
	--variable=lang:"$(DOCUMENT_LANG)" \
	--variable=title:"$(TITLE)" \
	--variable=author:"$(AUTHOR)" \
	--variable=advisor:"$(ADVISOR)" \
	--variable=university:"$(UNIVERSITY)" \
	--variable=department:"$(DEPARTMENT)" \
	--variable=research-group:"$(RESEARCH_GROUP)" \
	--variable=thesis-type:"$(THESIS_TYPE)" \
	--variable=lof \
	--variable=lot \
	--standalone \
	--table-of-contents \
	--bibliography=bibliography.bib \

LATEX_ARGS = \
	$(ARGS) \
	--template=template.latex \
	--variable=documentclass:report \
	--variable=fontsize:11pt \
	--variable=papersize:a4paper \
	--variable=sides:oneside \
	--variable=numbersections \
	--natbib \
	--variable=biblio-files:"bibliography" \
	--variable=biblio-style:"plain" \

HTML_ARGS = \
	--mathjax \
	--filter pandoc-citeproc \

# rules

## rules for compiling the document

pdf: latex build-latex


latex:
	pandoc \
		$(LATEX_ARGS) \
		--to=latex \
		--output=$(FILENAME).tex \

html:
	pandoc \
		$(FILES) \
		$(ARGS) \
		$(HTML_ARGS) \
		--to=html \
		--output=$(FILENAME).html \
		--css=buttondown.css \

epub:
	pandoc \
		$(FILES) \
		$(ARGS) \
		--output=$(FILENAME).epub \
		--css=buttondown.css \
		--epub-metadata=metadata.xml \

build-latex:
	pdflatex $(FILENAME).tex
#	bibtex $(FILENAME).aux
	pdflatex $(FILENAME).tex
#	pdflatex $(FILENAME).tex

## misc rules

open:
	gnome-open \
		$(FILENAME).pdf \

clean:
	rm -f *.tex *.aux *.dvi *.log *.pdf *.html *.mobi *.out *.epub
