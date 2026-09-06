# Public domain notice for all NCBI EDirect scripts is located at:
# https://www.ncbi.nlm.nih.gov/books/NBK179288/#chapter6.Public_Domain_Notice

# Authors: Jonathan Kans, Aaron Ucko

import subprocess
import shlex

def execute(cmmd, data=""):
	# the cmmd argument accepts either a flat string:
	#   "efetch -db nuccore -id NM_000518.5 -format fasta"
	# or a sequence of strings:
	#   ('efetch', '-db', 'nuccore', '-id', 'NM_000518.5', '-format', 'fasta')
	if isinstance(cmmd, str):
		cmmd = shlex.split(cmmd)
	res = subprocess.run(cmmd, input=data,
	                     capture_output=True,
	                     encoding='UTF-8')
	return res.stdout.strip()

def pipeline(cmmds, data=""):
	# the cmmds argument accepts either a flat string with piped commands:
	#   '''efetch -db nuccore -id NM_000518.5 -format gbc | xtract -insd CDS gene product'''
	# or a sequence of individual shell command strings to be joined with pipe symbols:
	#   ('efetch -db nuccore -id NM_000518.5 -format gbc', 'xtract -insd CDS gene product')
	# or a mixture of strings and sequences of strings:
	#   ('efetch -db nuccore -id NM_000518.5 -format gbc',
	#    ('xtract', '-insd', 'CDS', 'gene', 'product', 'feat_location'))
	def flatten(cmmd):
		if isinstance(cmmd, str):
			return cmmd
		else:
			return shlex.join(cmmd)
	if not isinstance(cmmds, str):
		cmmds = ' | '.join(map(flatten, cmmds))
	res = subprocess.run(cmmds, input=data, shell=True,
	                     capture_output=True,
	                     encoding='UTF-8')
	return res.stdout.strip()

def efetch(*, db, id, format, mode=""):
	# the efetch shortcut requires the use of named arguments:
	#   (db="nuccore", id="NM_000518.5", format="fasta")
	cmmd = ('efetch', '-db', db, '-id', str(id), '-format', format)
	if mode:
		cmmd = cmmd + ('-mode', mode)
	return execute(cmmd)
