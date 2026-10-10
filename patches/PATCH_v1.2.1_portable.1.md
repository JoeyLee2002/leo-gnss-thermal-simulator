# 1.2.1-portable.1 - No-installer distribution

Date: 2026-10-08

Before this change the existing source and documents were saved in the version archive labelled `before_portable_20261008`.

This is a packaging revision of application 1.2.1, not a new thermal solver version. It adds a Windows x64 launcher, complete copied Runtime R2021b Update 8, bilingual guides, critical-file integrity checks, process-local library paths, startup logs and relocation/smoke tests. No Runtime installer is run on the end user's machine; no persistent PATH or registry change is made. The full Runtime and its original notices are retained, and the user acknowledges its license on first interactive use.

Do not mark cross-machine acceptance complete until a relocated package has actually been tested on an independent target. Earlier server acceptance of the installed-Runtime build is separate evidence, not proof of this portable package. Application-level findings from the 2026-10-04 server test remain open.
