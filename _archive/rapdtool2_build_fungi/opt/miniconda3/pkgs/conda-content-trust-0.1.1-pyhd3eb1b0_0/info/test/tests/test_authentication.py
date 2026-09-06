# -*- coding: utf-8 -*-

""" tests.test_authentication

Unit tests for conda-content-trust/car/authentication.py
as well as integration tests for the signing.py + authentication.py.

Run the tests this way:
    pytest tests/test_authentication.py

"""

# Python2 Compatibility
from __future__ import absolute_import, division, print_function, unicode_literals

# std libs
import copy
import os

# dependencies
import pytest
import cryptography.exceptions

# this codebase
from conda_content_trust.authentication import *
from conda_content_trust.metadata_construction import (
        gen_keys, gen_and_write_keys, # for new-key tests
        # build_repodata_verification_metadata
        )
from conda_content_trust.common import (
        PrivateKey, PublicKey, keyfiles_to_bytes, keyfiles_to_keys,
        SignatureError, MetadataVerificationError)
from conda_content_trust.signing import wrap_as_signable, sign_signable

# Some REGRESSION test data.
REG__KEYPAIR_NAME = 'keytest_old'
REG__PRIVATE_BYTES = b'\xc9\xc2\x06\r~\r\x93al&T\x84\x0bI\x83\xd0\x02!\xd8\xb6\xb6\x9c\x85\x01\x07\xdat\xb4!h\xf97'
REG__PUBLIC_BYTES = b"\x01=\xddqIb\x86m\x12\xba[\xae'?\x14\xd4\x8c\x89\xcf\x07s\xde\xe2\xdb\xf6\xd4V\x1eR\x1c\x83\xf7"
REG__PUBLIC_HEX_ROOT = 'c8bd83b3bfc991face417d97b9c0db011b5d256476b602b92fec92849fc2b36c'
REG__MESSAGE_THAT_WAS_SIGNED = b'123456\x067890'
# Signature is over REG__MESSAGE_THAT_WAS_SIGNED using key REG__PRIVATE_BYTES.
REG__SIGNATURE = b'\xb6\xda\x14\xa1\xedU\x9e\xbf\x01\xb3\xa9\x18\xc9\xb8\xbd\xccFM@\x87\x99\xe8\x98\x84C\xe4}9;\xa4\xe5\xfd\xcf\xdaau\x04\xf5\xcc\xc0\xe7O\x0f\xf0F\x91\xd3\xb8"\x7fD\x1dO)*\x1f?\xd7&\xd6\xd3\x1f\r\x0e'
REG__SIGNATURE_HEX = 'b6da14a1ed559ebf01b3a918c9b8bdcc464d408799e8988443e47d393ba4e5fdcfda617504f5ccc0e74f0ff04691d3b8227f441d4f292a1f3fd726d6d31f0d0e'
# REG__HASHED_VAL = b'string to hash\n'
# REG__HASH_HEX = '73aec9a93f4beb41a9bad14b9d1398f60e78ccefd97e4eb7d3cf26ba71dbe0ce'
# #REG__HASH_BYTES = b's\xae\xc9\xa9?K\xebA\xa9\xba\xd1K\x9d\x13\x98\xf6\x0ex\xcc\xef\xd9~N\xb7\xd3\xcf&\xbaq\xdb\xe0\xce'
# REG__REPODATA_HASHMAP = {
#     "noarch/current_repodata.json": "908724926552827ab58dfc0bccba92426cec9f1f483883da3ff0d8664e18c0fe",
#     "noarch/repodata.json": "908724926552827ab58dfc0bccba92426cec9f1f483883da3ff0d8664e18c0fe",
#     "noarch/repodata_from_packages.json": "908724926552827ab58dfc0bccba92426cec9f1f483883da3ff0d8664e18c0fe",
#     "osx-64/current_repodata.json": "8120fb07a6a8a280ffa2b89fb2fbb89484823d0b0357ff0cfa7c333352b2faa2",
#     "osx-64/repodata.json": "8120fb07a6a8a280ffa2b89fb2fbb89484823d0b0357ff0cfa7c333352b2faa2",
#     "osx-64/repodata_from_packages.json": "8120fb07a6a8a280ffa2b89fb2fbb89484823d0b0357ff0cfa7c333352b2faa2"
# }
REG__TEST_TIMESTAMP = '2019-10-01T00:00:00Z'
REG__TEST_EXPIRY_DATE = '2025-01-01T10:30:00Z'
# REG__EXPECTED_UNSIGNED_REPODATA_VERIFY = {
#     'type': 'repodata_verify', 'timestamp': REG__TEST_TIMESTAMP,
#     'metadata_spec_version': '0.0.5', 'expiration': REG__TEST_EXPIRY_DATE,
#     'secured_files': {
#         'noarch/current_repodata.json': '908724926552827ab58dfc0bccba92426cec9f1f483883da3ff0d8664e18c0fe',
#         'noarch/repodata.json': '908724926552827ab58dfc0bccba92426cec9f1f483883da3ff0d8664e18c0fe',
#         'noarch/repodata_from_packages.json': '908724926552827ab58dfc0bccba92426cec9f1f483883da3ff0d8664e18c0fe',
#         'osx-64/current_repodata.json': '8120fb07a6a8a280ffa2b89fb2fbb89484823d0b0357ff0cfa7c333352b2faa2',
#         'osx-64/repodata.json': '8120fb07a6a8a280ffa2b89fb2fbb89484823d0b0357ff0cfa7c333352b2faa2',
#         'osx-64/repodata_from_packages.json': '8120fb07a6a8a280ffa2b89fb2fbb89484823d0b0357ff0cfa7c333352b2faa2'}
# }
# REG__EXPECTED_REGSIGNED_REPODATA_VERIFY = {
#     # Re-sign this if its data changes: it's signed!
#     'type': 'repodata_verify', 'timestamp': '2019-10-01T00:00:00Z',
#     'metadata_spec_version': '0.0.5', 'expiration': '2025-01-01T10:30:00Z',
#     'secured_files': {
#         'noarch/current_repodata.json': '908724926552827ab58dfc0bccba92426cec9f1f483883da3ff0d8664e18c0fe',
#         'noarch/repodata.json': '908724926552827ab58dfc0bccba92426cec9f1f483883da3ff0d8664e18c0fe',
#         'noarch/repodata_from_packages.json': '908724926552827ab58dfc0bccba92426cec9f1f483883da3ff0d8664e18c0fe',
#         'osx-64/current_repodata.json': '8120fb07a6a8a280ffa2b89fb2fbb89484823d0b0357ff0cfa7c333352b2faa2',
#         'osx-64/repodata.json': '8120fb07a6a8a280ffa2b89fb2fbb89484823d0b0357ff0cfa7c333352b2faa2',
#         'osx-64/repodata_from_packages.json': '8120fb07a6a8a280ffa2b89fb2fbb89484823d0b0357ff0cfa7c333352b2faa2'}
# }

TEST_ROOT_MD_V1 = {
  "signatures": {
    "c8bd83b3bfc991face417d97b9c0db011b5d256476b602b92fec92849fc2b36c": {
      "other_headers": "04001608001d162104917adb684e2e9fb5ed4e59909ddd19a1268b62d005025f96ff1a",
      "signature": "9327c2c4907c964741924420c4c35eb01805c15ec2fe5cad17bc98c0c3daf03006fcafb332eaa543a1ed212fac05f227662d8617970afc6c919ee4b78bacb004"
    }
  },
  "signed": {
    "delegations": {
      "key_mgr": {
        "pubkeys": [
          "013ddd714962866d12ba5bae273f14d48c89cf0773dee2dbf6d4561e521c83f7"
        ],
        "threshold": 1
      },
      "root": {
        "pubkeys": [
          "c8bd83b3bfc991face417d97b9c0db011b5d256476b602b92fec92849fc2b36c"
        ],
        "threshold": 1
      }
    },
    "expiration": "2021-10-26T16:53:46Z",
    "metadata_spec_version": "0.6.0",
    "timestamp": "2020-10-26T16:53:46Z",
    "type": "root",
    "version": 1
  }
}

TEST_ROOT_MD_V2 = {
  "signatures": {
    "a59cea0987ee9046d68d2d011e919eb9278e3f478cca77f5204d65191ff8d7a5": {
      "other_headers": "04001608001d1621040a14b126c986f276831c7b04134f35b47db4364305025f96ff1b",
      "signature": "d406839499630a75350ba6f6c009aae173f15dd8c9be069c9b535ff77b6d624d6092487fe18e2c4f5c13b252a3ebe3f89ab15f4c52c66db752f8cbbfc6d96609"
    },
    "c8bd83b3bfc991face417d97b9c0db011b5d256476b602b92fec92849fc2b36c": {
      "other_headers": "04001608001d162104917adb684e2e9fb5ed4e59909ddd19a1268b62d005025f96ff1b",
      "signature": "f4c13d4456028778026639fcdc63ec7d6005e1e88f2dcfaf87afa3b89ce6a1ec8938af83fdc9d3d7045d0ebd648654c6af027daaf7164e014a8a53f373e9b906"
    }
  },
  "signed": {
    "delegations": {
      "key_mgr": {
        "pubkeys": [
          "013ddd714962866d12ba5bae273f14d48c89cf0773dee2dbf6d4561e521c83f7"
        ],
        "threshold": 1
      },
      "root": {
        "pubkeys": [
          "c8bd83b3bfc991face417d97b9c0db011b5d256476b602b92fec92849fc2b36c"
        ],
        "threshold": 1
      }
    },
    "expiration": "2021-10-26T16:53:46Z",
    "metadata_spec_version": "0.6.0",
    "timestamp": "2020-10-26T16:53:46Z",
    "type": "root",
    "version": 2
  }
}



# NOTE to dev:
#  test_authenticate was originally a long sequence of tests in a single
#  function.  I pulled out most of it, and what remains is has to be compared
#  to the new tests to see if it's still useful.
def test_wrap_sign_verify_signable():

    # Make a new keypair.  Returns keys and writes keys to disk.
    # Then load it from disk and compare that to the return value.  Exercise
    # some of the functions redundantly.
    generated_private, generated_public = gen_and_write_keys('keytest_new')
    loaded_new_private_bytes, loaded_new_public_bytes = keyfiles_to_bytes(
            'keytest_new')
    loaded_new_private, loaded_new_public = keyfiles_to_keys('keytest_new')

    old_private = PrivateKey.from_bytes(REG__PRIVATE_BYTES)
    old_public = PublicKey.from_bytes(REG__PUBLIC_BYTES)

    assert generated_private.is_equivalent_to(loaded_new_private)
    assert generated_public.is_equivalent_to(loaded_new_public)
    assert loaded_new_private.is_equivalent_to(
                PrivateKey.from_bytes(loaded_new_private_bytes))
    assert loaded_new_public.is_equivalent_to(
                PublicKey.from_bytes(loaded_new_public_bytes))


    # Clean up a bit for the next tests.
    new_private = loaded_new_private
    new_public = loaded_new_public
    del (
            loaded_new_public, loaded_new_private,
            generated_private, generated_public,
            loaded_new_private_bytes, loaded_new_public_bytes)




    # Test wrapping, signing signables, and verifying signables.
    d = {'foo': 'bar', '1': 2}
    d_modified = {'foo': 'DOOM', '1': 2}
    signable_d = wrap_as_signable(d)
    assert is_a_signable(signable_d)
    sign_signable(signable_d, old_private)
    assert is_a_signable(signable_d)

    verify_signable(
            signable=signable_d,
            authorized_pub_keys=[old_public.to_hex()],
            threshold=1)

    # Expect failure this time due to bad format.
    try:
        verify_signable(
                signable=signable_d['signed'],
                authorized_pub_keys=[old_public.to_hex()],
                threshold=1)
    except TypeError:
        pass
    else:
        assert False, 'Failed to raise expected exception.'

    # Expect failure this time due to non-matching signature.
    try:
        modified_signable_d = copy.deepcopy(signable_d)
        modified_signable_d['signed'] = d_modified
        verify_signable(
                signable=modified_signable_d,
                authorized_pub_keys=[old_public.to_hex()],
                threshold=1)
    except SignatureError:
        pass
    else:
        assert False, 'Failed to raise expected exception.'


    # Clean up a bit.
    for fname in [
            'keytest_new.pub', 'keytest_new.pri',
            'keytest_old.pri', 'keytest_old.pub']:
        if os.path.exists(fname):
            os.remove(fname)



# def test_repodata_verify_funcs():

#     # Test construction and verification of signed repodata_verify, including
#     # wrapping, signing the signable, and verifying the signables with a real
#     # example.
#     repodata_hashmap = {
#             "noarch/current_repodata.json":
#             "908724926552827ab58dfc0bccba92426cec9f1f483883da3ff0d8664e18c0fe",
#             "noarch/repodata.json":
#             "908724926552827ab58dfc0bccba92426cec9f1f483883da3ff0d8664e18c0fe",
#             "noarch/repodata_from_packages.json":
#             "908724926552827ab58dfc0bccba92426cec9f1f483883da3ff0d8664e18c0fe",
#             "osx-64/current_repodata.json":
#             "8120fb07a6a8a280ffa2b89fb2fbb89484823d0b0357ff0cfa7c333352b2faa2",
#             "osx-64/repodata.json":
#             "8120fb07a6a8a280ffa2b89fb2fbb89484823d0b0357ff0cfa7c333352b2faa2",
#             "osx-64/repodata_from_packages.json":
#             "8120fb07a6a8a280ffa2b89fb2fbb89484823d0b0357ff0cfa7c333352b2faa2"}

#     rd_v_md = build_repodata_verification_metadata(repodata_hashmap)
#     signable_rd_v_md = wrap_as_signable(rd_v_md)
#     assert is_a_signable(signable_rd_v_md)
#     sign_signable(signable_rd_v_md, old_private)
#     assert is_a_signable(signable_rd_v_md)

#     verify_signable(
#             signable=signable_rd_v_md,
#             authorized_pub_keys=[old_public.to_hex()],
#             threshold=1)

#     # Expect failure this time due to non-matching signature.
#     try:
#         modified_signable_rd_v_md = copy.deepcopy(signable_rd_v_md)

#         modified_signable_rd_v_md[
#                 'signed']['secured_files']['noarch/current_repodata.json'
#                 ] = modified_signable_rd_v_md['signed']['secured_files'][
#                 'noarch/current_repodata.json'][:-1] + 'f' # TODO: Generalize test condition. (Also, un-ugly.)

#         verify_signable(
#                 signable=modified_signable_rd_v_md,
#                 authorized_pub_keys=[old_public.to_hex()],
#                 threshold=1)
#     except SignatureError:
#         pass
#     else:
#         assert False, 'Failed to raise expected exception.'

#     # DEBUG: 💥💥💥💥 Dump the various bits and pieces for debugging.
#     #        Remove this.
#     with open('_test_output__repodata_hashmap.json', 'wb') as fobj:
#         fobj.write(canonserialize(repodata_hashmap))
#     with open('_test_output__repodata_verify.json', 'wb') as fobj:
#         fobj.write(canonserialize(signable_rd_v_md))


#     # Additional regression test for a file produced by the indexer.
#     # This should come up as good.
#     verify_signable(
#         signable={
#           "signatures": {
#             "013ddd714962866d12ba5bae273f14d48c89cf0773dee2dbf6d4561e521c83f7": "740a426113cb83a62e58eb41fcd0b5f36691b0b18bffbe7eb3da30b5baf83f6c703a0fdb584599702470c74f55572a27cf9de250fc3afb723c43fef4dc778401"
#           },
#           "signed": {
#             "expiration": "2019-10-28T15:36:32Z",
#             "metadata_spec_version": "0.0.4",
#             "secured_files": {
#               "noarch/current_repodata.json": "908724926552827ab58dfc0bccba92426cec9f1f483883da3ff0d8664e18c0fe",
#               "noarch/repodata.json": "908724926552827ab58dfc0bccba92426cec9f1f483883da3ff0d8664e18c0fe",
#               "noarch/repodata_from_packages.json": "908724926552827ab58dfc0bccba92426cec9f1f483883da3ff0d8664e18c0fe",
#               "osx-64/current_repodata.json": "fc9268ea2b4add37e090b7f2b2c88b95c513cab445fb099e8631d8815a384ae4",
#               "osx-64/repodata.json": "fc9268ea2b4add37e090b7f2b2c88b95c513cab445fb099e8631d8815a384ae4",
#               "osx-64/repodata_from_packages.json": "fc9268ea2b4add37e090b7f2b2c88b95c513cab445fb099e8631d8815a384ae4"
#             },
#             "timestamp": "2019-09-27T15:36:32Z",
#             "type": "repodata_verify"
#           }
#         },
#         authorized_pub_keys=[old_public.to_hex()],
#         threshold=1)


def test_sign_and_verify():
    """
    Tests functions:
        - sign
        - verify
    """

    # Generate new keys and construct key objects for old keys.
    new_private, new_public = gen_keys()
    old_private = PrivateKey.from_bytes(REG__PRIVATE_BYTES)
    old_public = PublicKey.from_bytes(REG__PUBLIC_BYTES)

    old_sig = old_private.sign(REG__MESSAGE_THAT_WAS_SIGNED)
    new_sig = new_private.sign(REG__MESSAGE_THAT_WAS_SIGNED)
    new_sig2 = new_private.sign(REG__MESSAGE_THAT_WAS_SIGNED)
    assert new_sig == new_sig2  # deterministic (obv not a thorough test)
    assert old_sig == REG__SIGNATURE # regression

    # Test verify()

    # Good signatures first.
    old_public.verify(REG__SIGNATURE, REG__MESSAGE_THAT_WAS_SIGNED)
    old_public.verify(old_sig, REG__MESSAGE_THAT_WAS_SIGNED)
    new_public.verify(new_sig, REG__MESSAGE_THAT_WAS_SIGNED)

    # Use wrong public key.
    wrong_pubkey_obj = PublicKey.from_hex(
            '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef')
    with pytest.raises(cryptography.exceptions.InvalidSignature):
        wrong_pubkey_obj.verify(REG__SIGNATURE, REG__MESSAGE_THAT_WAS_SIGNED)

    # Use bad data.
    with pytest.raises(cryptography.exceptions.InvalidSignature):
        old_public.verify(new_sig, REG__MESSAGE_THAT_WAS_SIGNED + b'a')

    with pytest.raises(cryptography.exceptions.InvalidSignature):
        new_public.verify(new_sig, REG__MESSAGE_THAT_WAS_SIGNED[0:-1])



def test_verify_signature():
    verify_signature(
            REG__SIGNATURE_HEX,
            PublicKey.from_bytes(REG__PUBLIC_BYTES),
            REG__MESSAGE_THAT_WAS_SIGNED)

    # invalid signatures
    with pytest.raises(cryptography.exceptions.InvalidSignature):
        verify_signature(
                REG__SIGNATURE_HEX[:-6] + 'ffffff', # wrong value
                PublicKey.from_bytes(REG__PUBLIC_BYTES),
                REG__MESSAGE_THAT_WAS_SIGNED)

    with pytest.raises(TypeError):
        verify_signature(
                REG__SIGNATURE_HEX[:-1], # wrong length
                PublicKey.from_bytes(REG__PUBLIC_BYTES),
                REG__MESSAGE_THAT_WAS_SIGNED)

    with pytest.raises(TypeError):
        verify_signature(
                REG__SIGNATURE, # wrong type
                PublicKey.from_bytes(REG__PUBLIC_BYTES),
                REG__MESSAGE_THAT_WAS_SIGNED)


    # other bad args
    with pytest.raises(cryptography.exceptions.InvalidSignature):
        verify_signature(
                REG__SIGNATURE_HEX, # wrong type
                PublicKey.from_bytes(REG__PUBLIC_BYTES),
                REG__MESSAGE_THAT_WAS_SIGNED + b'\xc9') # altered message

    with pytest.raises(cryptography.exceptions.InvalidSignature):
        verify_signature(
                REG__SIGNATURE_HEX,
                PublicKey.from_bytes(REG__PUBLIC_BYTES[:-4] + b'0000'), # wrong key
                REG__MESSAGE_THAT_WAS_SIGNED)

    with pytest.raises(TypeError):
        verify_signature(
                REG__SIGNATURE_HEX,
                REG__PUBLIC_BYTES,                  # wrong type
                REG__MESSAGE_THAT_WAS_SIGNED)

    with pytest.raises(TypeError):
        verify_signature(
                REG__SIGNATURE_HEX,
                PublicKey.from_bytes(REG__PUBLIC_BYTES),
                {'this is not bytes': 1})              # wrong type


# verify_root is also tested in test_root.py (but test_root.py expects GPG)
def test_verify_root():
    """
    Tests conda_content_trust.authentication.verify_root
    """

    # Root chaining: normal test
    verify_root(TEST_ROOT_MD_V1, TEST_ROOT_MD_V2)


    # Now we tinker a bit to break stuff.
    root_v2_edited = copy.deepcopy(TEST_ROOT_MD_V2)


    # Can't verify root v10 using root v1 (chaining)
    with pytest.raises(MetadataVerificationError):
        root_v2_edited['signed']['version'] = 10
        verify_root(TEST_ROOT_MD_V1, root_v2_edited)

    # Reset.
    root_v2_edited['signed']['version'] = TEST_ROOT_MD_V2['signed']['version']


    # Bad signature, same keys, same contents
    # with pytest.raises(cryptography.exceptions.InvalidSignature):
    with pytest.raises(SignatureError):
        sig = root_v2_edited['signatures'][REG__PUBLIC_HEX_ROOT]['signature']
        sig = sig[:-6] + 'ffffff'
        root_v2_edited['signatures'][REG__PUBLIC_HEX_ROOT]['signature'] = sig
        verify_root(TEST_ROOT_MD_V1, root_v2_edited)

    # Reset.
    root_v2_edited['signatures'] = copy.deepcopy(TEST_ROOT_MD_V2['signatures'])


    # Not enough signatures from authorized keys:
    #     Have one of the signatures claim to be from the wrong key.
    with pytest.raises(SignatureError):
        root_v2_edited['signatures'][REG__PUBLIC_HEX_ROOT[:-6] + 'ffffff'] \
                = root_v2_edited['signatures'][REG__PUBLIC_HEX_ROOT]
        del root_v2_edited['signatures'][REG__PUBLIC_HEX_ROOT]
        verify_root(TEST_ROOT_MD_V1, root_v2_edited)

    # Reset.
    root_v2_edited['signatures'] = copy.deepcopy(TEST_ROOT_MD_V2['signatures'])


    # Not enough signatures from authorized keys:
    #     Change the trusted metadata such that we expect sigs from 3 distinct
    #     authorized keys (and still provide only 2).
    with pytest.raises(SignatureError):
        root_v1_edited = copy.deepcopy(TEST_ROOT_MD_V1)
        root_v1_edited['signed']['delegations']['root']['threshold'] += 1
        verify_root(root_v1_edited, TEST_ROOT_MD_V2)

    # Reset.
    root_v1_edited['signed']['delegations']['root']['threshold'] -= 1



# def test_verify_delegation():
#     """
#     Tests conda_content_trust.authentication.verify_delegation
#     """
#     raise NotImplementedError('verify_delegation requires unit tests.')
