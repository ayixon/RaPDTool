=================
NEWS for lazr.uri
=================

1.0.6 (2021-09-13)
==================

- Adjust versioning strategy to avoid importing pkg_resources, which is slow
  in large environments.

1.0.5 (2020-06-29)
==================

- Add an explicit __hash__ method to lazr.uri.URI.

1.0.4 (2020-06-12)
==================

- Install version.txt with package_data (Stefano Rivera,
  https://bugs.launchpad.net/lazr.uri/+bug/918660).
- Switch from buildout to tox.

1.0.3 (2012-01-18)
==================

- Add compatibility with Python 3 (Thomas Kluyver).

1.0.1 (2009-06-01)
==================

- Eliminate dependency on setuptools_bzr so sdists do not bring bzr ini, among
  others.

1.0 (2009-03-23)
================

- Initial release on PyPI
