## Twitterapi

An unofficial twitter api client that performs readonly actions against the twitter api. These actions are:

* Getting user information
* Getting user tweets
* Searching for users with keyword
* Searching for tweets with keyword

## Note

In order to compile or use this project as a library you need to have the nim compiler installed and the nimble package manager installed

## Usage

This project can be used as a cli tool by simply compiling it with

```bash
nimble make
```

or, it can be imported as a library by importing the api.nim file from the project

```nim
import twitterapipkg / [api]
```

## As a cmdline tool

After compiling the project simply run

```bash
./bin/twitterapi -h
```

a help message will be displayed showing how to use the tool to retreive information from twitter

## As a nim library

Clone this repo, in the project root directory type `nimble install` now you can import this project from your nim projects.

To view the documentation just navigate to your nimble directory (directory where nimble stores installed libraries) look for the twitterapi library and inside the library use

`nim doc` followed by the file whose documentation you wish to view
