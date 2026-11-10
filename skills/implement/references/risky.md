# Renames and removals

Read this at implement's step 2, before a rename, retype, or move that breaks
callers, or before removing a guard, a retry, or a special case.

A rename, retype, or move that breaks callers goes expand, migrate, contract,
as the plan's items or, with no plan, in that order, and one that touches
stored or serialized data calls the Skill tool with `eng:blast-radius` first.
Before removing a guard, a retry, or a special case, call the Skill tool with
`eng:why`, even when the request named the removal. When it finds a reason the
code still serves, keep the code and bring the reason back to the user.
