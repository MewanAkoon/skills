# Design red flags

Four shapes that read as reasonable in a sketch and cost you after the code
lands. Screen the sketch against each one. A flag is a reason to revise the
shape, not a reason to add a comment explaining it.

## Shallow module

A shallow module has a large interface and hides little behind it. Judge depth
by how much behaviour and policy sit behind the public interface, measured
against the size of that interface.

The signs:

- The caller drives several methods to finish one operation.
- Public options name internal stages or implementation choices.
- Learning the interface does not save the caller from learning the
  implementation.

A deep module is not a deep call chain. A chain spreads understanding across
layers. A deep module gathers capability behind one interface.

## Information leakage

Two modules depend on the same internal decision, so changing a
representation, a policy, or a protocol detail means editing both in step.

Re-exporting a transport or wire type is the common case. Parse external data
into a domain type behind the interface, and keep storage schemas, framework
objects, and protocol details private to the module that owns them.

## Temporal decomposition

Modules split by when they run rather than by what they know. Separate load,
validate, transform, and save stages repeat one representation and its
invariants across every boundary.

Group by the knowledge a module owns. Two methods that run at different times
belong in one module when they protect the same decision.

## Pass-through method

A method that forwards the same arguments to a method of the same shape. It
adds a layer and hides nothing.

Delete it, or move the responsibility to the module that can finish the
operation. Keep a forwarding boundary when it adds policy, adapts between two
representations, or draws a real abstraction.

---

Condensed from John Ousterhout, *A Philosophy of Software Design*.
