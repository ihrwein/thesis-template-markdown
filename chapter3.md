# Language bindings in syslog-ng

Syslog-ng is a log management software. It is written in C which offers high
performance but makes the development much harder: it can be learned easily but
writing good code is very hard. If a system administrator needs a feature he cannot
develop that without C programming experience. Also, legacy codes needs an
extra care because a little change in one place can easily alter the execution
of other parts. Nevertheless, they are very likely to be able to write Python
or Perl code in some level.

Today's technologies are focused around Big Data projects. Hadoop, Elastic Search,
Kafka are all written in Java. Their official libraries are maintained while
the other language bindings aren't so feature rich or not maintained so well.

Rust is different from the other mentioned languages in that, it is compiled
into native code. Rust's runtime isn't bigger than the C's one and doesn't
support garbage collection. The language is built to support compatibility
with the existing C libraries and has its novel ownership and borrowing rules
which ease to write safe and fast programs.

## General concept

The general concept is built on the following aspects:
* syslog-ng-core is written in C and offers services to modules,
* a module can be written in any language which has bindings for syslog-ng.

`syslog-ng-core` can be used for message processing, filtering, multiplexing
and demultiplexing. Modules provide additional features such as the ability
to send messages into an Elastic cluster or parsing the messages with Python
functions. 

Python and Java are not native languages. They have to use explicitly written
bindings to work. These bindings resides in their own modules and are able to dynamically
load several Java or Python plugins. For example a Java destination can be loaded
if the user knows its class name and sets the proper `classpath`.

## syslog-ng's module system

syslog-ng loads its modules from shared object files (`.so`). They are under
the `$prefix/lib/syslog-ng` directory. A module can contain zero or more plugins.

Every module has to export some variables and functions. The `module_info` (of
type `ModuleInfo`) constant `struct` contains some basic information about the
module itself ( `name`, `description`, etc.) and a pointer (`plugins`) to a
`Plugin` array. A `Plugin` has a `name`, a `type` (parser, filter, etc.) and a
`parser` field which points at a `CfgParser` instance. The `CfgParser` `struct`
contains a function pointer to a generated grammar parser function and some
fields as well.

Loading a plugin is requested by syslog-ng's configuration grammar. When it
encounters a valid identifier which is not defined as a keyword it tries to
find a plugin with that name and with the type of the actual context in the
grammar. If it finds a plugin, it loads its contents and calls the grammar's
parser function.

## `*-sys` crates

Rust and Cargo has a convention about how to deal with crates which provide
language bindings for native libraries. These crates should be named like
`foo-sys` where the name of the native library is `libfoo`.

`sys` crates should provide only the low level bindings, the higher level
code should go into other crates.

Using `sys` crates simplifies the linking and makes possible to easily create
higher level crates.

