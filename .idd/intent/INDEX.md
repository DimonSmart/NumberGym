# IDD Intent Index

This index helps humans and Coding Agents find relevant current intent documents.
It is not the source of truth.

Current `IDD-NNNN` documents directly under `.idd/intent/` contain normative
product intent, ADRs, or active spikes.

`GLOSSARY.md`, when present, is an optional unnumbered vocabulary support file
and is not listed in this index.

Git history is the source for deleted or previous document versions.

## Current documents

The `Document` column contains stable `IDD-NNNN` identifiers only. Do not put
filenames, file paths, or Markdown links in this column. Resolve an identifier to
the unique current `.idd/intent/IDD-NNNN.*.md` file when the document must be
opened.

| Document | Role | Area | Notes | Replaces |
| --- | --- | --- | --- | --- |
| IDD-0001 | Specification | NumberGym | Number, time, and phone language training | |
| IDD-0002 | Specification | VerbGym | Verb-form language training | |
| IDD-0003 | Specification | Shared trainer UI | Application screens and navigation | |
| IDD-0004 | Specification | Shared trainer UI | Training interaction modes | |
| IDD-0005 | Specification | Shared trainer experience | Progress and gamification | |
| IDD-0006 | Specification | Trainer platform | Shared application integration | |
| IDD-0007 | ADR | Trainer platform | Flutter and modular product boundary | |
