# Ranger

## Introduction

Ranger fetches RIR statistics files from APNIC, and uses it to generate a routing table grouped by countries and locations. It is for academic use *ONLY*. It could be used to observe network behavior under different routing policies.

## Usage

Run `npm install` to install all dependencies.

Specify a configuration file with command line option `-c FILE`. As an example, please see `config.sexp.example`. Countries and locations names are represented by two capital letters, as is the case in RIR statistics files. Providing a `*` would match all countries and locations that have not been specified. Note that for duplicate rules, the last always wins. You can also add individual routing policies.

By default, pipe the output to `bash` would add all routes. Specify command line option `-d` to delete corresponding items.
