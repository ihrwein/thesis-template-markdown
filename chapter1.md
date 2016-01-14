# Introduction

This document summarizes my work during my internship at Balabit. I
worked on areas related to my Master Thesis but they are distinct from it. Most
of my task was to integrate my log parser and correlation libraries to the
`syslog-ng` log management software.

The subject of my thesis is to create a log parsing and correlation library.
My internship focused on creating Rust bindings for syslog-ng and investigate
the Reactor design pattern in Rust.

In the first chapter I describe how the Reactor pattern can be implemented in
Rust.  The reactor runs in its own thread so I wrote about threads and channels
as well.

The second chapter goes into details of the interaction between the C and Rust
languages. This chapter contains information about how function calls work between the
two languages. It also describes the general concept of language bindings in
syslog-ng and its module system.

Finally, the third chapter presents several iterations of the design of the
Rust language bindings.

