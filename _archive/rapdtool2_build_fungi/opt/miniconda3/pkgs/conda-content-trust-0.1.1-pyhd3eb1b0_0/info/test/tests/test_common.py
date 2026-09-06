# -*- coding: utf-8 -*-

""" tests.test_common

(Mostly) unit tests for conda-content-trust/conda_content_trust/common.py.

Run the tests this way:
    pytest tests/test_common.py

"""

# Python2 Compatibility
from __future__ import absolute_import, division, print_function, unicode_literals

import os

import pytest

from conda_content_trust.common import *

# A 40-hex-character GPG public key fingerprint
SAMPLE_FINGERPRINT = 'f075dd2f6f4cb3bd76134bbb81b6ca16ef9cd589'
SAMPLE_UNKNOWN_FINGERPRINT = '0123456789abcdef0123456789abcdef01234567'

# The real key value of the public key (q, 32-byte ed25519 public key val),
# as a length-64 hex string.
SAMPLE_KEYVAL = 'bfbeb6554fca9558da7aa05c5e9952b7a1aa3995dede93f3bb89f0abecc7dc07'

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
    'key_mgr.json': {'pubkeys': [], 'threshold': 1},
    'root.json': {
      'pubkeys': ['bfbeb6554fca9558da7aa05c5e9952b7a1aa3995dede93f3bb89f0abecc7dc07'],
      'threshold': 1}
  },
  'expiration': '2020-12-09T17:20:19Z',
  'metadata_spec_version': '0.1.0',  # TODO ✅⚠️❌💣: Update to 0.6.0 and remove the ".json" in the delegation names above, update the pubkey, and then re-sign this test metadata with the updated pubkey and adjust SAMPLE_GPG_SIG
  'type': 'root',
  'version': 1
}

SAMPLE_GPG_SIG = {
  'see_also': 'f075dd2f6f4cb3bd76134bbb81b6ca16ef9cd589',
  'other_headers': '04001608001d162104f075dd2f6f4cb3bd76134bbb81b6ca16ef9cd58905025defd3d3',
  'signature': 'd6a3754dbd604a703434058c70db6a510b84a571236155df0b1f7f42605eb9e0faabca111d6ee808a7fcba663eafb5d66ecdfd33bd632df016fde3aed0f75201'
}

SAMPLE_SIGNED_ROOT_MD = {
  'signatures': {
    'bfbeb6554fca9558da7aa05c5e9952b7a1aa3995dede93f3bb89f0abecc7dc07': SAMPLE_GPG_SIG
  },
  'signed': SAMPLE_ROOT_MD_CONTENT
}

EXPECTED_SERIALIZED_SAMPLE_SIGNED_ROOT_MD = (b'{\n  '
    b'"signatures": {\n    '
        b'"bfbeb6554fca9558da7aa05c5e9952b7a1aa3995dede93f3bb89f0abecc7dc07": {\n      '
            b'"other_headers": "04001608001d162104f075dd2f6f4cb3bd76134bbb81b6ca16ef9cd58905025defd3d3",\n      '
            b'"see_also": "f075dd2f6f4cb3bd76134bbb81b6ca16ef9cd589",\n      '
            b'"signature": "d6a3754dbd604a703434058c70db6a510b84a571236155df0b1f7f42605eb9e0faabca111d6ee808a7fcba663eafb5d66ecdfd33bd632df016fde3aed0f75201"\n    }\n  },\n  '
    b'"signed": {\n    '
        b'"delegations": {\n      '
            b'"key_mgr.json": {\n        '
                b'"pubkeys": [],\n        '
                b'"threshold": 1\n      },\n      '
            b'"root.json": {\n        '
                b'"pubkeys": [\n          "bfbeb6554fca9558da7aa05c5e9952b7a1aa3995dede93f3bb89f0abecc7dc07"\n        ],\n        '
                b'"threshold": 1\n      }\n    },\n    '
                b'"expiration": "2020-12-09T17:20:19Z",\n    '
                b'"metadata_spec_version": "0.1.0",\n    '  # TODO ✅⚠️❌💣: Update to 0.6.0 and remove the ".json" in the delegation names above, update the pubkey, and then re-sign this test metadata with the updated pubkey and adjust SAMPLE_GPG_SIG
                b'"type": "root",\n    '
                b'"version": 1\n  }\n}')

# # Some REGRESSION test data.
# REG__KEYPAIR_NAME = 'keytest_old'
REG__PRIVATE_BYTES = b'\xc9\xc2\x06\r~\r\x93al&T\x84\x0bI\x83\xd0\x02!\xd8\xb6\xb6\x9c\x85\x01\x07\xdat\xb4!h\xf97'
REG__PUBLIC_BYTES = b"\x01=\xddqIb\x86m\x12\xba[\xae'?\x14\xd4\x8c\x89\xcf\x07s\xde\xe2\xdb\xf6\xd4V\x1eR\x1c\x83\xf7"
REG__PUBLIC_HEX = '013ddd714962866d12ba5bae273f14d48c89cf0773dee2dbf6d4561e521c83f7'
REG__PRIVATE_HEX = 'c9c2060d7e0d93616c2654840b4983d00221d8b6b69c850107da74b42168f937'
# REG__MESSAGE_THAT_WAS_SIGNED = b'123456\x067890'
# # Signature is over REG__MESSAGE_THAT_WAS_SIGNED using key REG__PRIVATE_BYTES.
# REG__SIGNATURE = b'\xb6\xda\x14\xa1\xedU\x9e\xbf\x01\xb3\xa9\x18\xc9\xb8\xbd\xccFM@\x87\x99\xe8\x98\x84C\xe4}9;\xa4\xe5\xfd\xcf\xdaau\x04\xf5\xcc\xc0\xe7O\x0f\xf0F\x91\xd3\xb8"\x7fD\x1dO)*\x1f?\xd7&\xd6\xd3\x1f\r\x0e'
REG__HASHED_VAL = b'string to hash\n'
REG__HASH_HEX = '73aec9a93f4beb41a9bad14b9d1398f60e78ccefd97e4eb7d3cf26ba71dbe0ce'
# #REG__HASH_BYTES = b's\xae\xc9\xa9?K\xebA\xa9\xba\xd1K\x9d\x13\x98\xf6\x0ex\xcc\xef\xd9~N\xb7\xd3\xcf&\xbaq\xdb\xe0\xce'



# def test_sha512256():
#     # Test the SHA-512-truncate-256 hashing function w/ an expected result.
#     assert sha512256(REG__HASHED_VAL) == REG__HASH_HEX

#     # TODO: Test more?  Unusual input



def test_canonserialize():

    # Simple primitives
    assert canonserialize('') == b'""'
    assert canonserialize('a') == b'"a"'
    assert canonserialize(12) == b'12'
    assert canonserialize(SAMPLE_KEYVAL) == (
            b'"bfbeb6554fca9558da7aa05c5e9952b7a1aa3995dede93f3bb89f0abecc7dc07"')

    # Tuples
    assert canonserialize((1, 2, 3)) == b'[\n  1,\n  2,\n  3\n]'
    assert canonserialize(('ABC', 1, 16)) == b'[\n  "ABC",\n  1,\n  16\n]'

    # Dictionaries indexed by ints, strings, or both
    assert canonserialize({}) == b'{}'
    assert canonserialize({1: 'v1', 2: 'v2'}) == (
            b'{\n  "1": "v1",\n  "2": "v2"\n}')
    assert canonserialize({'a': 'v1', 'b': 'v2'}) == (
            b'{\n  "a": "v1",\n  "b": "v2"\n}')
    with pytest.raises(TypeError):
        # Currently, json.dumps(...sort_keys=True) raises a TypeError while
        # sorting if it has to sort string keys and integer keys together.
        canonserialize({5: 'value', 'key': 9, 'key2': 'value2'})

    assert canonserialize(SAMPLE_SIGNED_ROOT_MD) == (
            EXPECTED_SERIALIZED_SAMPLE_SIGNED_ROOT_MD)

    # TODO: Tricksy tests that mess with encoding.



def test_keyfile_operations():
    """
    Unit tests for functions:
        keyfiles_to_keys
        keyfiles_to_bytes
    """
    # Test keyfiles_to_keys and keyfiles_to_bytes
    # Regression: load old key pair, two ways.
    # First, dump them to temp files (to test keyfiles_to_keys).
    with open('keytest_old.pri', 'wb') as fobj:
        fobj.write(REG__PRIVATE_BYTES)
    with open('keytest_old.pub', 'wb') as fobj:
        fobj.write(REG__PUBLIC_BYTES)
    loaded_old_private_bytes, loaded_old_public_bytes = keyfiles_to_bytes(
            'keytest_old')
    loaded_old_private, loaded_old_public = keyfiles_to_keys('keytest_old')

    # Clean up a bit.
    for fname in ['keytest_old.pri', 'keytest_old.pub']:
        if os.path.exists(fname):
            os.remove(fname)

    # Check the keys we wrote and then loaded.
    assert loaded_old_private_bytes == REG__PRIVATE_BYTES
    assert loaded_old_public_bytes == REG__PUBLIC_BYTES



def test_key_functions():
    # """
    # Tests for functions:
    #     from_bytes
    #     from_hex
    #     to_bytes
    #     to_hex
    #     is_equivalent_to
    # """
    # First key, generated in two ways:
    private_1_byt = PrivateKey.from_bytes(b'1'*32)
    private_1_hex = PrivateKey.from_hex('31'*32)  # hex representation of b'1'

    # Second key, generated in two ways:
    private_2_byt = PrivateKey.from_bytes(b'10' + b'1'*30)
    private_2_hex = PrivateKey.from_hex('3130' + '31'*30)

    # Regression key, generated in two ways:
    private_reg_byt = PrivateKey.from_bytes(REG__PRIVATE_BYTES)
    private_reg_hex = PrivateKey.from_hex(REG__PRIVATE_HEX)


    # Check these against each other and also against the expected output:
    #   - to_bytes
    #   - to_hex
    #   - is_equivalent_to
    #   - from_bytes
    #   - from_hex

    # key 1 from bytes vs key 1 from hex, also vs raw key 1 value
    assert private_1_byt.is_equivalent_to(private_1_hex)
    assert private_1_hex.is_equivalent_to(private_1_byt)
    assert b'1'*32 == private_1_byt.to_bytes() == private_1_hex.to_bytes()
    assert '31'*32 == private_1_byt.to_hex() == private_1_hex.to_hex()

    # key 1 vs key 2 vs regression key
    assert not private_1_byt.is_equivalent_to(private_2_byt)
    assert not private_2_byt.is_equivalent_to(private_1_byt)
    assert not private_1_byt.is_equivalent_to(private_2_hex)
    assert not private_2_hex.is_equivalent_to(private_1_byt)
    assert not private_reg_byt.is_equivalent_to(private_1_byt)
    assert not private_1_byt.is_equivalent_to(private_reg_byt)

    # key 2 from bytes vs key 2 from hex, also vs raw key 2 value
    assert private_2_byt.is_equivalent_to(private_2_hex)
    assert private_2_hex.is_equivalent_to(private_2_byt)
    assert b'10' + b'1'*30 == private_2_byt.to_bytes() == private_2_hex.to_bytes()
    assert '3130' + '31'*30 == private_2_byt.to_hex() == private_2_hex.to_hex()

    # regression key from bytes vs from hex, and vs raw key value
    assert private_reg_byt.is_equivalent_to(private_reg_hex)
    assert private_reg_hex.is_equivalent_to(private_reg_byt)
    assert REG__PRIVATE_BYTES == private_reg_byt.to_bytes()
    assert REG__PRIVATE_BYTES == private_reg_hex.to_bytes()
    assert REG__PRIVATE_HEX == private_reg_byt.to_hex()
    assert REG__PRIVATE_HEX == private_reg_hex.to_hex()


    # Test the behavior when is_equivalent_to is provided a bad argument.
    for bad_argument in ['1', 1, '1'*32, REG__PRIVATE_BYTES, b'1'*31, b'1'*33]:
        with pytest.raises(TypeError):
            private_reg_byt.is_equivalent_to(bad_argument)



# This is the version of the tests before PrivateKey and PublicKey classes were
# created to cut down on the utility function noise and make things easier to
# work with.
# def test_key_functions():
#     """
#     Unit tests for functions:
#         keyfiles_to_keys
#         keyfiles_to_bytes
#         key_to_bytes
#         public_key_from_bytes
#         private_key_from_bytes
#         keys_are_equivalent
#     """
#
#     # Test keyfiles_to_keys and keyfiles_to_bytes
#     # Regression: load old key pair, two ways.
#     # First, dump them to temp files (to test keyfiles_to_keys).
#     with open('keytest_old.pri', 'wb') as fobj:
#         fobj.write(REG__PRIVATE_BYTES)
#     with open('keytest_old.pub', 'wb') as fobj:
#         fobj.write(REG__PUBLIC_BYTES)
#     loaded_old_private_bytes, loaded_old_public_bytes = keyfiles_to_bytes(
#             'keytest_old')
#     loaded_old_private, loaded_old_public = keyfiles_to_keys('keytest_old')
#
#     # Clean up a bit.
#     for fname in ['keytest_old.pri', 'keytest_old.pub']:
#         if os.path.exists(fname):
#             os.remove(fname)
#
#     # Check the keys we wrote and then loaded.
#     assert loaded_old_private_bytes == REG__PRIVATE_BYTES
#     assert loaded_old_public_bytes == REG__PUBLIC_BYTES
#
#     # Test key object construction (could also call it "key loading")
#     other_private = private_key_from_bytes(b'1'*32)
#     other_private_dupe = private_key_from_bytes(b'1'*32)
#     other_public = public_key_from_bytes(b'2'*32)
#     other_public_dupe = public_key_from_bytes(b'2'*32)
#     for bad_argument in ['1', 1, '1'*32, loaded_old_private, b'1'*31, b'1'*33]:
#         with pytest.raises((TypeError, ValueError)):
#             public_key_from_bytes(bad_argument)
#         with pytest.raises((TypeError, ValueError)):
#             private_key_from_bytes(bad_argument)
#
#     # Test key equivalence checker.
#     assert keys_are_equivalent(other_private, other_private_dupe)
#     assert keys_are_equivalent(other_public, other_public_dupe)
#     assert not keys_are_equivalent(other_private, other_public)
#     assert not keys_are_equivalent(loaded_old_private, loaded_old_public)
#     assert not keys_are_equivalent(loaded_old_private, other_private)
#
#     for bad_argument in ['1', 1, '1'*32, REG__PRIVATE_BYTES, b'1'*31, b'1'*33]:
#         with pytest.raises(TypeError):
#             keys_are_equivalent(bad_argument, loaded_old_private)
#         with pytest.raises(TypeError):
#             keys_are_equivalent(loaded_old_private, bad_argument)
#         with pytest.raises(TypeError):
#             keys_are_equivalent(bad_argument, bad_argument)
#
#
#     # Test key_to_bytes
#     assert REG__PUBLIC_BYTES == key_to_bytes(loaded_old_public)
#     assert REG__PRIVATE_BYTES == key_to_bytes(loaded_old_private)
#     for bad_argument in ['1', 1, '1'*32, REG__PRIVATE_BYTES, b'1'*32]:
#         with pytest.raises(TypeError):
#             key_to_bytes(bad_argument)
#
#
#     # # Make a new keypair.  Returns keys and writes keys to disk.
#     # # Then load it from disk and compare that to the return value.  Exercise
#     # # some of the functions redundantly.
#     # assert keys_are_equivalent(generated_public, loaded_new_public)
#     # assert keys_are_equivalent(
#     #         loaded_new_private,
#     #         private_key_from_bytes(loaded_new_private_bytes))
#     # assert keys_are_equivalent(
#     #         loaded_new_public, public_key_from_bytes(loaded_new_public_bytes))



# Pull these from the integration tests in test_authentication.py


def test_is_gpg_signature():
    """
    Tests:
        is_gpg_signature
        checkformat_gpg_signature
        is_a_signature (only for cases relevant to gpg signatures)
        checkformat_signature (only for cases relevant to gpg signatures)
    """

    def expect_success(sig):
        checkformat_gpg_signature(sig)
        checkformat_signature(sig)
        assert is_gpg_signature(sig)
        assert is_a_signature(sig)

    def expect_failure(sig, exception_class):
        with pytest.raises(exception_class):
            checkformat_gpg_signature(sig)
        with pytest.raises(exception_class):
            checkformat_signature(sig)
        assert not is_gpg_signature(sig)
        assert not is_a_signature(sig)

    gpg_sig = {
            'other_headers': '04001608001d162104f075dd2f6f4cb3bd76134bbb81b6ca16ef9cd58905025defd3d3',
            'signature': 'd6a3754dbd604a703434058c70db6a510b84a571236155df0b1f7f42605eb9e0faabca111d6ee808a7fcba663eafb5d66ecdfd33bd632df016fde3aed0f75201'
    }

    expect_success(gpg_sig)

    # Add optional fingerprint entry.
    gpg_sig['see_also'] = 'f075dd2f6f4cb3bd76134bbb81b6ca16ef9cd589'
    expect_success(gpg_sig)

    # Too short
    gpg_sig['see_also'] = gpg_sig['see_also'][:-1]
    expect_failure(gpg_sig, ValueError)

    # Nonsense
    expect_failure(42, TypeError)

    del gpg_sig['see_also']

    # Also too short
    gpg_sig['signature'] = gpg_sig['signature'][:-1]
    expect_failure(gpg_sig, ValueError)








# def test_wrap_as_signable():
#     raise(NotImplementedError())

# def test_is_a_signable():
#     raise(NotImplementedError())

# def test_is_hex_signature():
#     raise(NotImplementedError())

def test_is_hex_key():
    assert is_hex_key('00' * 32)
    assert is_hex_key(SAMPLE_KEYVAL)
    assert not is_hex_key('00' * 31)
    assert not is_hex_key('00' * 33)
    assert not is_hex_key('00' * 64)
    assert not is_hex_key('1g' * 32)
    assert not is_hex_key(b'1g' * 32)

    pubkey_bytes = binascii.unhexlify(SAMPLE_KEYVAL)
    assert not is_hex_key(pubkey_bytes)

    public = PublicKey.from_bytes(pubkey_bytes)
    assert not is_hex_key(public)
    assert is_hex_key(public.to_hex())

def test_checkformat_hex_string():
    # TODO ✅: Add other tests.
    with pytest.raises(ValueError):
        checkformat_hex_string('A') # single case is important
    checkformat_hex_string('a')
    checkformat_hex_string(SAMPLE_KEYVAL)

# def test_checkformat_hex_key():
#     raise NotImplementedError()

# def test_checkformat_list_of_hex_keys():
#     raise NotImplementedError()

# def test_checkformat_byteslike():
#     raise NotImplementedError()

# def test_checkformat_natural_int():
#     raise NotImplementedError()

# def test_checkformat_expiration_distance():
#     raise NotImplementedError()

# def test_checkformat_utc_isoformat():
#     raise NotImplementedError()

# def test_checkformat_gpg_fingerprint():
#     raise NotImplementedError()

# def test_checkformat_gpg_signature():
#     raise NotImplementedError()


def test_checkformat_delegation():
    # TODO ✅: Add other tests.
    with pytest.raises(TypeError):
        checkformat_delegation(1)
    with pytest.raises(ValueError):
        checkformat_delegation({})
    with pytest.raises(ValueError):
        checkformat_delegation({
            'threshold': 0, 'pubkeys': ['01'*32]})
    with pytest.raises(ValueError):
        checkformat_delegation({
            'threshold': 1.5, 'pubkeys': ['01'*32]})
    checkformat_delegation({
        'threshold': 1, 'pubkeys': ['01'*32]})

    with pytest.raises(ValueError):
        checkformat_delegation({
            'threshold': 1, 'pubkeys': ['01'*31]})

    with pytest.raises(ValueError):
        checkformat_delegation({
            'threshold': 1, 'pubkeys': ['01'*31]})



def test_checkformat_delegating_metadata():

    checkformat_delegating_metadata(SAMPLE_SIGNED_ROOT_MD)
    # TODO ✅: Add a few other kinds of valid metadata to this test:
    #           - key_mgr metadata:
    #               - one signed using raw ed25519, one signed using OpenPGP
    #               - one with and one without version provided
    #           - root metadata:
    #               - one signed using raw ed25519 instead of OpenPGP


    for badval in [
            SAMPLE_ROOT_MD_CONTENT,
            # TODO ✅: Add more bad values (bad sig formats, etc.)
            ]:
        with pytest.raises( (TypeError, ValueError) ):
            checkformat_delegating_metadata(badval)




# def test_iso8601_time_plus_delta():
#     raise NotImplementedError()

# def test_is_hex_string():
#     raise(NotImplementedError())

# def test_set_expiry():
#     raise NotImplementedError()

