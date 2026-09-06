# -*- coding: utf-8 -*-

""" tests.test_root

Some integration tests tests for conda-content-trust that focus on
generation, signing, and verification of root metadata.  This tests GPG
integration via securesystemslib if securesystemslib can be successfully
imported.

IN CONTINUOUS INTEGRATION, this set of tests should be run with and without
securesystemslib and GPG available on the system.

Run the tests this way:
    pytest tests/test_root.py

"""

# Python2 Compatibility
from __future__ import absolute_import, division, print_function, unicode_literals

import copy
import json

import pytest

# securesystemslib is an optional dependency, and required only for signing
# root metadata via GPG.  Verification of those signatures, and signing other
# metadata with raw ed25519 signatures, does not require securesystemslib.
try:
    import securesystemslib.gpg.functions as gpg_funcs
    import securesystemslib.formats
    SSLIB_AVAILABLE = True
except ImportError:
    SSLIB_AVAILABLE = False

import conda_content_trust.common as common
import conda_content_trust.metadata_construction as metadata_construction
import conda_content_trust.signing as signing
import conda_content_trust.root_signing as root_signing
import conda_content_trust.authentication as authentication

# Note that changing these sample values breaks the sample signature, so you'd
# have to generate a new one.

# A 40-hex-character GPG public key fingerprint
SAMPLE_FINGERPRINT = '917adb684e2e9fb5ed4e59909ddd19a1268b62d0'
SAMPLE_UNKNOWN_FINGERPRINT = '0123456789abcdef0123456789abcdef01234567'

# The real key value of the public key (q, 32-byte ed25519 public key val),
# as a length-64 hex string.
SAMPLE_KEYVAL = 'c8bd83b3bfc991face417d97b9c0db011b5d256476b602b92fec92849fc2b36c'

SAMPLE_GPG_KEY_OBJ = {
  'creation_time': 1571411344,
  'hashes': ['pgp+SHA2'],
  'keyid': SAMPLE_FINGERPRINT,
  'keyval': {
    'private': '',
    'public': {'q': SAMPLE_KEYVAL}
  },
  'method': 'pgp+eddsa-ed25519',
  'type': 'eddsa'
}

SAMPLE_ROOT_MD_CONTENT = {
  'delegations': {
    'key_mgr': {'pubkeys': [], 'threshold': 1},
    'root': {
      'pubkeys': ['c8bd83b3bfc991face417d97b9c0db011b5d256476b602b92fec92849fc2b36c'],
      'threshold': 1}
  },
  'expiration': '2030-12-09T17:20:19Z',
  'metadata_spec_version': '0.6.0',
  'type': 'root',
  'version': 1
}

# To generate a new signature after changing SAMPLE_ROOT_MD_CONTENT:
# >  serialized = common.canonserialize(SAMPLE_ROOT_MD_CONTENT)
# >  new_sig = root_signing.sign_via_gpg(serialized, SAMPLE_FINGERPRINT)
# If desired, you can add:  new_sig['see_also'] = SAMPLE_FINGERPRINT to keep
# the optional value listed (the OpenPGP fingerprint of the signing key).
SAMPLE_GPG_SIG = {
  'see_also': '917adb684e2e9fb5ed4e59909ddd19a1268b62d0', # optional entry
  'other_headers': '04001608001d162104917adb684e2e9fb5ed4e59909ddd19a1268b62d005025f970318',
  'signature': '41867f58064c89acb300b1b42f4d59ec52e11e6aab05cb7f651345d878ee06d3a4f32411646134e112a7d8adc1d1304f63fb918b57cac449baba36ef0a1fbe07'}

SAMPLE_SIGNED_ROOT_MD = {
  'signatures': {
    SAMPLE_KEYVAL: SAMPLE_GPG_SIG},
  'signed': SAMPLE_ROOT_MD_CONTENT}

def test_gpg_key_retrieval_with_unknown_fingerprint():
    if not SSLIB_AVAILABLE:
        pytest.skip(
                '--TEST SKIPPED⚠️ : Unable to use GPG key retrieval or '
                'signing without securesystemslib and GPG.')
        return

    # TODO✅: Adjust this to use whatever assertRaises() functionality the
    #         testing suite we're using provides.


    with pytest.raises(securesystemslib.gpg.exceptions.KeyNotFoundError):
        full_gpg_pubkey = gpg_funcs.export_pubkey(SAMPLE_UNKNOWN_FINGERPRINT)

    print(
            '--TEST SUCCESS✅: detection of error when we pass an unknown '
            'key fingerprint to GPG for retrieval of the full public key.')



def test_gpg_signing_with_unknown_fingerprint():
    if not SSLIB_AVAILABLE:
        pytest.skip(
                '--TEST SKIPPED⚠️ : Unable to use GPG key retrieval or '
                'signing without securesystemslib and GPG.')
        return

    # TODO✅: Adjust this to use whatever assertRaises() functionality the
    #         testing suite we're using provides.
    try:
        gpg_sig = root_signing.sign_via_gpg(
                b'1234', SAMPLE_UNKNOWN_FINGERPRINT)
    except securesystemslib.gpg.exceptions.CommandError as e:
        # TODO✅: This is a clumsy check.  It's a shame we don't get better
        #         than CommandError(), but this will do for now.
        assert 'signing failed: No secret key' in e.args[0]
    else:
        assert False, 'Expected CommandError was not raised!'

    print(
            '--TEST SUCCESS✅: detection of error when we pass an unknown '
            'key fingerprint to GPG for signing.')


# def test_gpg_verification_compared_to_ssls():





def test_root_gen_sign_verify():
    # Integration test

    # Build a basic root metadata file with empty key_mgr delegation and one
    # root key, threshold 1, version 1.
    rmd = metadata_construction.build_root_metadata(
            root_version=1,
            root_pubkeys=[SAMPLE_KEYVAL], root_threshold=1,
            key_mgr_pubkeys=[], key_mgr_threshold=1)
    rmd = signing.wrap_as_signable(rmd)

    signed_portion = rmd['signed']

    canonical_signed_portion = common.canonserialize(signed_portion)


    if not SSLIB_AVAILABLE:
        pytest.skip(
                '--TEST SKIPPED⚠️ : Unable to perform GPG signing without '
                'securesystemslib and GPG.')
        return

    # gpg_key_obj = securesystemslib.gpg.functions.export_pubkey(
    #         SAMPLE_FINGERPRINT)

    gpg_sig = root_signing.sign_via_gpg(
            canonical_signed_portion, SAMPLE_FINGERPRINT)

    signed_rmd = copy.deepcopy(rmd)

    signed_rmd['signatures'][SAMPLE_KEYVAL] = gpg_sig



    # # Dump working files
    # with open('T_gpg_sig.json', 'wb') as fobj:
    #     fobj.write(common.canonserialize(gpg_sig))

    # with open('T_gpg_key_obj.json', 'wb') as fobj:
    #     fobj.write(common.canonserialize(gpg_key_obj))

    # with open('T_canonical_sigless_md.json', 'wb') as fobj:
    #     fobj.write(canonical_signed_portion)

    # with open('T_full_rmd.json', 'wb') as fobj:
    #     fobj.write(common.canonserialize(signed_rmd))



    # Verify using the SSL code and the expected pubkey object.
    # # (Purely as a test -- we wouldn't normally do this.)
    # verified = securesystemslib.gpg.functions.verify_signature(
    #     gpg_sig, gpg_key_obj, canonical_signed_portion)

    # assert verified

    authentication.verify_gpg_signature(
            gpg_sig, SAMPLE_KEYVAL, canonical_signed_portion)

    print(
            '--TEST SUCCESS✅: GPG signing (using GPG and securesystemslib) and '
            'GPG signature verification (using only cryptography)')



def test_verify_existing_root_md():

    # It's important that we are able to verify root metadata without anything
    # except old root metadata, so in particular we don't want to need the
    # full GPG public key object.  Ideally, we want only the Q value of the
    # key, but if we also need to retain the GPG key fingerprint (listed in the
    # signature itself), we can do that.....

    # with open('T_full_rmd.json', 'rb') as fobj:
    #     signed_rmd = json.load(fobj)
    #
    # gpg_sig = signed_rmd['signatures'][
    #     'bfbeb6554fca9558da7aa05c5e9952b7a1aa3995dede93f3bb89f0abecc7dc07']
    #
    # canonical_signed_portion = common.canonserialize(signed_rmd['signed'])
    #
    # with open('T_gpg_key_obj.json', 'rb') as fobj:
    #     gpg_key_obj = json.load(fobj)
    # q = gpg_key_obj['keyval']['public']['q']
    # fingerprint = gpg_key_obj['keyid']


    canonical_signed_portion = common.canonserialize(
            SAMPLE_ROOT_MD_CONTENT)

    # # First, try using securesystemslib's GPG signature verifier directly.
    # verified = securesystemslib.gpg.functions.verify_signature(
    #     SAMPLE_GPG_SIG,
    #     SAMPLE_GPG_KEY_OBJ,  # <-- We don't want conda to have to provide this.
    #     canonical_signed_portion)

    # assert verified

    # # Second, try it using my adapter, skipping a bit of ssl's process.
    # verified = root_signing.verify_gpg_sig_using_ssl(
    #         SAMPLE_GPG_SIG,
    #         SAMPLE_FINGERPRINT,
    #         SAMPLE_KEYVAL,
    #         canonical_signed_portion)

    # assert verified

    # Third, use internal code only.  (This is what we're actually going to
    # use in conda.)

    # Verify using verify_gpg_signature.
    authentication.verify_gpg_signature(
    # authentication.verify_gpg_signature(
            SAMPLE_GPG_SIG,
            SAMPLE_KEYVAL,
            canonical_signed_portion)

    print(
            '--TEST SUCCESS✅: GPG signature verification without using GPG or '
            'securesystemslib')

    # Verify using verify_signable.
    authentication.verify_signable(
            SAMPLE_SIGNED_ROOT_MD, [SAMPLE_KEYVAL], 1, gpg=True)


    # TODO ✅: Add a v2 of root to this test, and verify static v2 via v1 as
    #          well.  Also add failure modes (verifying valid v2 using v0
    #          expectations.)
