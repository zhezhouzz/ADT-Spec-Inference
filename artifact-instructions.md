# Artifact Guide: Data-Driven Abductive Inference of Library Specifications

This document describes installation and use of Elrond, an OCaml tool
for data-driven abduction of black-box library method specifications.
This is the accompanying artifact for the OOPSLA 2021 submission
*Data-Driven Abductive Inference of Library Specifications* by Zhou et
al.


## TODO

* Should we publish a Docker image instead of asking evaluators to
  build the Dockerfile directly?
  + [ZZ] Not sure, their website mentions "dockerfile", I think it's
    Ok. Anyway, as the artifact is developing thus dockerfile is
    better.
  + [RD] I'm guessing it's fine to submit a Dockerfile, but having the
    image ready to go would save a bunch of the evaluators' time. So,
    publishing an image seems like the nice thing to do if we have the
    time / resources. I'll leave this TODO here, but maybe we should
    consider it lower priority / nice-to-have.

* Add a section about the Coq formalization.

* Annotate the artifact structure.

* Improve output of the benchmark script; currently difficult to
  correlate the script's output to our evaluation figure (Table 4).
  There are several columns in Table 4; does our benchmark script give
  us all of these numbers?

* Document the input file formats.


## Requirements

* Docker, which may be installed according to [the official
  installation instructions](https://docs.docker.com/get-docker/).
  This guide was tested using Docker version 20.10.7, but any
  contemporary Docker version is expected to work.


## Getting Started

1. Ensure Docker is installed. (On *nix, `sudo docker run hello-world`
will test your installation.) If Docker is not installed, install it
via the [official installation guide](https://docs.docker.com/get-docker/).

2. Navigate to the location of the Elrond Docker file.

   ```# cd <Dockerfile dir>```

3. Build the Elrond Docker image.

    ```# docker build --build-arg CACHEBUST=$(date +%s) . --tag elrond```

4. Launch a shell in the Elrond Docker image.

    ```# docker run -it elrond```

5. Print the Elrond's help message to verify the tool was installed
   successfully.

    ```$ ./main.exe --help```

6. When you are finished, you may stop the Elrond image by terminating
the shell with `exit`.


## Using Elrond

### Running All Benchmarks and Build Tables

Experimental results on the benchmark suite displayed in Table 4 of
the paper can be obtained via the
`~/ADT-Lemma-Discovery/build_table4.py` script in the Docker image
as follows:

##### Config File

* We use config file in json format to describe the source file, assertion file, output directory and details arguments for each benchmark. There are two config files:
  + `config/table4.config` for reviewers to run consistent inference and weakening inference by themselvies, the output directory of it is empty.
  + As the weakening inference may take several hours, we provides our consistent inference and weakening inference result under the output directory of `config/result_table4.config` as some command takes serveral hours to run. Don't use this config file do inference which will corrupt the saved expirement result.

##### Running All Benchmarks

* `python3 build_table4.py consistent config/table4.config` finds consistent specification
  mappings which enable successful verifications, but does not find
  weakenings of these specifications.
  
* `python3 build_table4.py weakening config/table4.config [option]` finds consistent and maximal specification
  mappings which enable successful verifications. 
  + There are `6` benchmarks we labeled as `Limit` in Table 4 which will take more than `1` hour to finish, we recommand you run the shorter benchmarks first(`-s`). 
  + `python3 build_table4.py weakening config/table4.config -s` will run all benchmarks besides these `6` benchmarks.
  + `python3 build_table4.py weakening config/table4.config -l` will run these `6` benchmarks.
  + `python3 build_table4.py weakening config/table4.config -s -l` will run all benchmarks.
  + `python3 build_table4.py weakening config/table4.config -tb 3600 -l` sets the time bound(in seconds) for weakening inference, the default time bound is `3600` seconds.
  
##### Additonal Processing

* There are two columns in the table needs the additional processing, notice that these processing are not a part of our tool, but just used to build the table.

* `python3 build_table4.py diff <config_file>` calculate the time needed for the SMT solver to find a sample allowed by aweakened solution but not the initial one (`time𝑑`).

* `python3 build_table4.py count <config_file> [option]` count total positive feature vectors in the space of weakenings(`|𝜙+|`).
  + There are `3` cells in the Table 4 of our paper are colored as blue, indicate the `3` timeout benchmarks when weakening. We use the weakened specification(instead of maximal one) to count the positive feature vectors in the space of weakenings. As these benchmarks are complicate, thus the counting may also cout long time(hours). We recommand you run the shorter benchmarks first(`-s`). 
  + `python3 build_table4.py count <config_file> -s` counts `|𝜙+|` for all benchmarks except these `3` benchmarks.
  + `python3 build_table4.py count <config_file> -l` counts `|𝜙+|` for these `3` benchmarks.
  + `python3 build_table4.py count <config_file> -s -l` counts `|𝜙+|` for all benchmarks.
  
##### Build Tables
  
* `python3 build_table4.py table <config_file>` shows the Table 4. Users can display the table at any stage of benchmark running, the missing cell or empty cell will be shown as `None`. 
* Notice that, the build table may be different from the table shown in our paper, however the numbers should be close.  The reason of difference may be:
  + The inference is based on the random generation, thus some intermidate statistic data are uncertained(i.g. `|𝑐𝑒𝑥|`, `#Gather` and `|𝜙+|`).
  + The performance statistic data(i.g `time_c`, `time_w`, `time_d`) depends on the machine you use.

* There is an comprehensive script: `~/ADT-Lemma-Discovery/auto_build_table4.sh` which builds the table from our saved expirement result.

### Running Individual Benchmarks

Elrond requires both a source file and assertion file as input, and
outputs results in JSON format to some output directory. The input
source and assertion files for the benchmark suite are located in the
`~/ADT-Lemma-Discovery/data` directory in the Docker image.

The command to run an individual benchmark without weakening is:

```./main.exe infer consistent <source_file> <assertion_file> <output_dir>```

For example,

```$ ./main.exe infer consistent data/bankersq.ml data/bankersq_assertion1.ml bankersq_out```

will run the `bankersq` benchmark, writing results to the
`_bankersq_out` directory.

To find weakened specification mappings, first run the benchmark without
weakening as above, then say:

```./main.exe infer weakening <output_dir>```

on the same `<output_dir>`.

For example,

```$ ./main.exe infer weakening bankersq_out```

will perform weakening on the `bankersq` benchmark we executed above.

Alternately, you may run the full inference-with-weakening pipeline
at once by saying:

```./main.exe infer full <source_file> <assertion_file> <output_dir>```

For example, we can recreate the `bankersq` output directory in one pass:

    $ rm -rf _bankersq_out
    $ ./main.exe infer full data/bankersq.ml data/bankersq_assertion1.ml bankersq_out


### Running Other Programs

To run Elrond on your own programs, you must provide both an input
OCaml code listing and an assertion file.

+ source file:

```c
(* Signature of library *)
module type DT_NAME = sig
  type TP_NAME
  ...
  val VAR: FUNC_TP
  ...
end

(* type of client *)
val VAR: FUNC_TP

(* implementation of client *)
let [rec] VAR (VAR: ARG_TP) ... = EXPR
```

```c
DT_NAME:= string
TP_NAME:= string | DT_NAME "." TP_NAME
ARG_TP:= "int" | "bool" | TP_NAME
RET_TP:= "int" | "bool" | TP_NAME | "(" FUNC_TP "," ... ")"
FUNC_TP:= RET_TP | ARG_TP "->" FUNC_TP

VAR := string
VAR_TUPLE := VAR | "(" VAR "," ... ")"
Lit := integer | boolean
OP := "+" | "<=" | ">=" | ">" | "<" | "=="
FUNC_APP := FUNC_NAME | FUNC_APP VAR
CASE := "| _ when" EXPR "->" EXPR
EXPR :=
| "if" FUNC_APP "then" EXPR "else" EXPR
| VAR
| EXPR OP EXPR
| "(" EXPR "," ... ")"
| FUNC_NAME
| EXPR EXPR
| "let" VAR_TUPLE : ARG_TP "=" EXPR "in" EXPR
| match VAR_TUPLE with CASE ...
```
+ The type in signature should be abstract.
+ The input type of function is a list of "ARG_TP", the output type of function are written as a tuple. 
+ The condition of "if" should be a single function application. 
+ The matched case in "match" are written as "| _ -> when CASE" instead of "| CASE"(we use ocaml parser which asks the matched case be an application of data type constrcutor, put the CASE after when can get round this limitation. In our situation the datatype is abstract and we do not distinguish if it is a constructor.)
+ New variable should be typed when it first appears(we do not do type inference).
+ All variables have distinct names(we do not do alpha renaming now).

+ assertion:

```c
(* Predicates *)
let preds = [| PRED; ...|]

(* Precondtion, which is optional *)
let pre VAR (IVAR: ARG_TP) ... (OVAR: ARG_TP) ... (QVAE: ARG_TP) ... = ASSERTION
(* Postcondtion *)
let post VAR (IVAR: ARG_TP) ... (OVAR: ARG_TP) ... (QVAE: ARG_TP) ... = ASSERTION
```

```c
DT_NAME:= string
TP_NAME:= string | DT_NAME "." TP_NAME
ARG_TP:= "int" | "bool" | TP_NAME

IVAR := string
OVAR := string
QVAR := string

PRED := "mem" | "hd" | "ord" | "once" | "left" | "right" | "para" | "ance" | "root"
OP := "==" | "!=" | "<=" | ">=" | "<" | ">"

ASSERTION :=
| PRED VAR ...
| VAR OP VAR
| implies ASSERTION ASSERTION
| iff ASSERTION ASSERTION
| ASSERTION "&&" ASSERTION
| ASSERTION "||" ASSERTION
| NOT ASSERTION
```

+ Impelementation of libraries and impelementation of predicates are fixed now, thus user cannot define their own libraries/predicaets. But user can define their own assertions.

## Artifact Structure

This section gives a brief overview of the files in this artifact.

TODO: Annotate the basic layout of the artifact code.