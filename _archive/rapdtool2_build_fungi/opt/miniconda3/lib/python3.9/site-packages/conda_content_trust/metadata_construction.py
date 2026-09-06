# -*- coding: utf-8 -*-

""" conda_content_trust.metadata_construction

This module contains functions that construct metadata and generate signing
keys.

Function Manifest for this Module

Key Creation:
  gen_keys
  gen_and_write_keys

Metadata Construction:
  build_delegating_metadata
  build_root_metadata         (wraps build_delegating_metadata)

"""
# Python2 Compatibility
from __future__ import absolute_import, division, print_function, unicode_literals

# std libs
import datetime

# dependencies
from six import string_types

# Default expiration distance for repodata_verify.json.
REPODATA_VERIF_MD_EXPIRY_DISTANCE = datetime.timedelta(days=31)
ROOT_MD_EXPIRY_DISTANCE = datetime.timedelta(days=365)

# car modules
from .common import (
        PrivateKey, PublicKey,
        checkformat_natural_int, checkformat_list_of_hex_keys,
        checkformat_string, checkformat_utc_isoformat, is_hex_hash,
        checkformat_delegation, checkformat_delegations, is_delegations,
        iso8601_time_plus_delta, SECURITY_METADATA_SPEC_VERSION)


def build_delegating_metadata(
        metadata_type,
        delegations=None, version=1, timestamp=None, expiration=None):
    """
    # ✅ TODO: Docstring

    Builds delegating metadata, e.g. root.json, key_mgr.json.

    See metadata specification at:
    anaconda.atlassian.net/wiki/spaces/AD/pages/285147281/Conda+Security+Metadata+Specification

    Arguments:
        metadata_type:
            The type of this metadata (e.g. root or key_mgr).  This should
            match the intended filename (without .json)

        delegations (default {} )
            a dictionary defining the delegations this metadata makes.
            Each key is the role delegated to, with the value equal to a
            dictionary listing the acceptable public keys and threshold
            (number of signatures from distinct acceptable public keys) for the
            delegated role.  e.g.
            {   'root.json':
                    {'pubkeys': ['01'*32, '02'*32, '03'*32], 'threshold': 2},
                'key_mgr.json':
                    {'pubkeys': ['04'*32], 'threshold': 1}}

            If not provided, an empty dictionary (no delegations) will be used.

        version (default 1)
            the version of the metadata; root metadata must advance one version
            at a time (root chaining).  For other types of metadata, versions
            are advisory.

        timestamp (default: current system time)
            UTC time associated with the production of this metadata, in
            ISO8601 format (e.g. '2020-10-31T14:45:19Z')

        expiration (default: current system time plus ROOT_MD_EXPIRY_DISTANCE)
            UTC time beyond which this metadata should be considered expired
            and not verifiable by any client seeking new metadata
    """

    # Handle optional args
    if delegations is None:
        delegations = {}
    if timestamp is None:
        timestamp = iso8601_time_plus_delta(datetime.timedelta(0)) #now plus 0
    if expiration is None:
        expiration = iso8601_time_plus_delta(ROOT_MD_EXPIRY_DISTANCE)

    # Argument validation.  Note that this (checkformat_delegations) also
    # checks for duplicates in lists of keys, which is important to reduce the
    # odds of a developer introducing certain bugs that cause security issues
    # (multiple signatures from same key being treated as two unique sigs,
    # etc.)
    checkformat_string(metadata_type)
    # TODO: ✅⚠️ Consider a set of acceptable metadata types (root, key_mgr,
    #             channel_authority).  Have to be careful about backward
    #             compatibility, though....
    checkformat_utc_isoformat(timestamp)
    checkformat_utc_isoformat(expiration)
    checkformat_natural_int(version)
    checkformat_delegations(delegations)

    md = {
        'type': metadata_type,
        'version': version,
        'metadata_spec_version': SECURITY_METADATA_SPEC_VERSION,
        'timestamp': timestamp,
        'expiration': expiration,
        "delegations": delegations
    }

    # # This very redundant, but might be useful as defensive code.
    # checkformat_delegating_metadata(wrap_as_signable(md)

    return md



def build_root_metadata(
        root_version,
        root_pubkeys, root_threshold,
        key_mgr_pubkeys, key_mgr_threshold,
        root_timestamp=None, root_expiration=None):
    """
    Wrapper for build_delegating_metadata().  Helpfully requires root to list
    itself and key_mgr in its delegations.

    # ✅ TODO: Docstring

    # ✅ TODO: Expand build_root_metadata flexibility for
    #          directly-root-delegated roles (i.e. in addition to channeler).
    """

    # Note that argument validation is performed in the
    # build_delegation_metadata call below.  So is some of the optional
    # argument default setting (timestamp).  We set expiration explicitly here
    # in case the defaults for generic delegating metadata and root metadata
    # diverge later.
    # Note that it is probably best to provide less revealing timestamps for
    # root metadata generation (00:00:00 of a past day), since it is a manual
    # process and patterns in that information might be somewhat useful to a
    # sophisticated attacker.
    if root_expiration is None:
        root_expiration = iso8601_time_plus_delta(ROOT_MD_EXPIRY_DISTANCE)
    # if channeler_pubkeys is None:
    #     channeler_pubkeys = []
    # if channeler_threshold = None:
    #     channeler_threshold = max(1, len(channeler_pubkeys))

    delegations = {
        'root':
            {'pubkeys': root_pubkeys, 'threshold': root_threshold},
        'key_mgr':
            {'pubkeys': key_mgr_pubkeys, 'threshold': key_mgr_threshold}
    }

    root_md = build_delegating_metadata(
            metadata_type='root', delegations=delegations,
            version=root_version, timestamp=root_timestamp,
            expiration=root_expiration)

    return root_md



def gen_and_write_keys(fname):
    """
    Generate an ed25519 key pair, then write the key files to disk.

    Given fname, write the private key to fname.pri, and the public key to
    fname.pub. Performs no filename validation, etc.  Also returns the private
    key object and the public key object, in that order.
    """

    # Create an ed25519 key pair, employing OS random generation.
    # Note that this just has the private key sitting around.  In the real
    # implementation, we'll want to use an HSM equipped with an ed25519 key.
    private, public = gen_keys()

    # Write the actual bytes of the key values to disk as requested.
    # Note that where the private key is concerned, we're just grabbing the
    # not-encrypted private key value.
    with open(fname + '.pri', 'wb') as fobj:
            fobj.write(private.to_bytes())
    with open(fname + '.pub', 'wb') as fobj:
            fobj.write(public.to_bytes())

    return private, public



def gen_keys():
    """
    Generate an ed25519 key pair and return it (private key, public key).

    Returns two objects:
      - a conda_content_trust.common.PrivateKey, a subclass of
        cryptography.hazmat.primitives.asymmetric.ed25519.Ed25519PrivateKey
      - a conda_content_trust.common.PublicKey, a subclass of
        cryptography.hazmat.primitives.asymmetric.ed25519.Ed25519PublicKey
    """
    # Create an ed25519 key pair, employing OS random generation.
    # Note that this just has the private key sitting around.  In the real
    # implementation, we'll want to use an HSM equipped with an ed25519 key.
    private = PrivateKey.generate()
    public = private.public_key()

    return private, public




## Moved to cli.py
# def interactive_modify_metadata(metadata):
#     """
#     """

#     # Update version if there is a version.
#     # Update timestamp if there is a timestamp.
#     #
#     # Show metadata contents ('signed') -- pprint?
#     #    indicate updated version/timestamp
#     #
#     # Changes phase:
#     #    Prompt to
#     #       (m) modify a value, (a) add a new entry, (d) delete an entry,
#     #       (r) revert to original, (f) finish and sign ((move on to signing
#     #       prompts))
#     #
#     # Signing phase:
#     #   Show metadata again, ask if metadata looks right
#     #   Show what keys the original was signed by and ask if those should be
#     #     the keys used for the new version.
#     #        ((Later: if root, vet against contents of new and old root versions))
#     #   Prompt for key (raw key file, raw key data, or gpg key fingerprint)
#     #   Sign using the given key (gpg if gpg, else normal signing mechanism).
#     #   Write (making sure not to overwrite, and -- if root -- making sure to
#     #     prepend "<version>." to root.json file.


#     try:
#         import pygments
#         import pygments.lexers
#         import pygments.formatters
#         import json
#     except ImportError():
#         print(
#                 'Unable to use interactive-modify-metadata mode: missing '
#                 'optional dependency "pygments" (for JSON syntax '
#                 'highlighting).  Please install pygments and try again.')
#         raise

#     done = False
#     while not done:







#     formatted_metadata = json.dumps(metadata, sort_keys=True, indent=4)

#     colorful_json = pygments.highlight(
#             formatted_metadata.encode('utf-8'),
#             pygments.lexers.JsonLexer(),
#             pygments.formatters.TerminalFormatter())
#     print(colorful_json)



#     ### Pull modified from debugging script
#     ### Pull modified from debugging script
#     ### Pull modified from debugging script



# This function is not in use.  It's here for reference, in case it's useful
# again in the future.
# def build_repodata_verification_metadata(
#         repodata_hashmap, channel=None, expiry=None, timestamp=None):
#     """
#     # TODO: ✅ Full docstring.

#     # TODO: ✅ Contemplate the addition of "version" to this metadata.  As yet,
#     #          the timestamp serves our purposes....

#     Note that if expiry or timestamp are not provided or left as None, now is
#     used for the timestamp, and expiry is produced using a default expiration
#     distance, via iso8601_time_plus_delta().  (It does not mean no expiration!)

#     Channel may be optionally specified, and is only included if specified.

#     Sample input (repodata_hashmap):
#     {
#         "noarch/current_repodata.json": "908724926552827ab58dfc0bccba92426cec9f1f483883da3ff0d8664e18c0fe",
#         "noarch/repodata.json": "...",
#         "noarch/repodata_from_packages.json": "...",
#         "osx-64/current_repodata.json": "...",
#         "osx-64/repodata.json": "...",
#         "osx-64/repodata_from_packages.json": "..."
#     }

#     Sample output:
#         See metadata specification (version defined by
#         SECURITY_METADATA_SPEC_VERSION) for definition and samples of type
#         "Repodata Verification Metadata".
#     """

#     if expiry is None:
#         expiry = iso8601_time_plus_delta(REPODATA_VERIF_MD_EXPIRY_DISTANCE)

#     if timestamp is None:
#         timestamp = iso8601_time_plus_delta(datetime.timedelta(0))

#     # TODO: ✅ More argument validation: channel, 
#     checkformat_utc_isoformat(expiry)
#     checkformat_utc_isoformat(timestamp)
#     if not ( # dict with string keys and 32-byte-hash-as-hex-string values
#             isinstance(repodata_hashmap, dict)
#             and all([isinstance(x, string_types) for x in repodata_hashmap])
#             and all([is_hex_hash(repodata_hashmap[x]) for x in repodata_hashmap])):
#         raise ValueError(
#                 'Argument repodata_hashmap must be a dictionary with strings '
#                 'as keys (filenames of repodata.json files), and values that '
#                 'are 64-character hex strings representing 32-byte hashes (of '
#                 'those repodata.json files)')

#     # TODO: ✅ Really have to make TypeError and ValueError usages consistent
#     #       with norms throughout this codebase.


#     rd_v_md = {
#             'type': 'repodata_verify',
#             # (Take advantage of iso8601_time_plus_delta() to get current time
#             #  in the ISO8601 UTC format we want.)
#             'timestamp': timestamp, # version->timestamp in spec v 0.0.5
#             'metadata_spec_version': SECURITY_METADATA_SPEC_VERSION,
#             'expiration': expiry,
#             'secured_files': repodata_hashmap}

#     if channel is not None:
#         rd_v_md['channel'] = channel

#     return rd_v_md
