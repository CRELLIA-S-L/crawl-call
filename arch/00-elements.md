# Elements

`E-NNN` — the parts this system is made of.

Each record names what the part is responsible for, the files it is made of, and — unless the project derives them from those files — the requirements it carries.
The join points one way: an element names its requirements, and a requirement never names an element.

Cut the parts as coarsely as the system allows.
An element per module says nothing the file tree did not; an element per boundary somebody could cross without noticing is what this layer is for.

The format is in `arch/README.md`.

*None at the moment.*
