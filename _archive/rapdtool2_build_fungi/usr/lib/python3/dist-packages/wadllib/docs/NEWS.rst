================
NEWS for wadllib
================

1.3.6 (2021-09-13)
==================

- Remove buildout support in favour of tox.  [bug=922605]
- Adjust versioning strategy to avoid importing pkg_resources, which is slow
  in large environments.

1.3.5 (2021-01-20)
==================

- Drop support for Python 3.2, 3.3, and 3.4.
- Accept Unicode parameter values again when performing multipart/form-data
  encoding on Python 2 (broken in 1.3.3).

1.3.4 (2020-04-29)
==================

- Advertise support for Python 3.8.
- Add Python 3.9 compatibility by using xml.etree.ElementTree if
  xml.etree.cElementTree does not exist.  [bug=1870294]

1.3.3 (2018-07-20)
==================

- Drop support for Python < 2.6.
- Add tox testing support.
- Implement a subset of MIME multipart/form-data encoding locally rather
  than using the standard library's email module, which doesn't have good
  handling of binary parts and corrupts bytes in them that look like line
  endings in various ways depending on the Python version.  [bug=1729754]

1.3.2 (2013-02-25)
==================

- Impose sort order to avoid test failures due to hash randomization.
  LP: #1132125
- Be sure to close streams opened by pkg_resources.resource_stream() to avoid
  test suite complaints.


1.3.1 (2012-03-22)
==================

- Correct the double pass through _from_string causing datetime issues


1.3.0 (2012-01-27)
==================

- Add Python 3 compatibility

- Add the ability to inspect links before following them.

- Ensure that the sample data is packaged.

1.2.0 (2011-02-03)
==================

- It's now possible to examine a link before following it, to see
  whether it has a WADL description or whether it needs to be fetched
  with a general HTTP client.

- It's now possible to iterate over a resource's Parameter objects
  with the .parameters() method.

1.1.8 (2010-10-27)
==================

- This revision contains no code changes, but the build system was
  changed (yet again).  This time to include the version.txt file
  used by setup.py.

1.1.7 (2010-10-26)
==================

- This revision contains no code changes, but the build system was
  changed (again) to include the sample data used in tests.

1.1.6 (2010-10-21)
==================

- This revision contains no code changes, but the build system was
  changed to include the sample data used in tests.

1.1.5 (2010-05-04)
==================

- Fixed a bug (Launchpad bug 274074) that prevented the lookup of
  parameter values in resources associated directly with a
  representation definition (rather than a resource type with a
  representation definition). Bug fix provided by James Westby.

1.1.4 (2009-09-15)
==================

- Fixed a bug that crashed wadllib unless all parameters of a
  multipart representation were provided.

1.1.3 (2009-08-26)
==================

- Remove unnecessary build dependencies.

- Add missing dependencies to setup file.

- Remove sys.path hack from setup.py.

1.1.2 (2009-08-20)
==================

- Consistently handle different versions of simplejson.

1.1.1 (2009-07-14)
==================

- Make wadllib aware of the <option> tags that go beneath <param> tags.

1.1 (2009-07-09)
================

- Make wadllib capable of recognizing and generating
  multipart/form-data representations, including representations that
  incorporate binary parameters.


1.0 (2009-03-23)
================

- Initial release on PyPI
