{ lib, runCommand, writeShellApplication, writeText, git, openssh, gnupg }: (
  { name
  , rev
  , verifyCommit
  , verifyTag
  , publicKeys
  , leaveDotGit
  , fetchresult
  }:
  let
    keysPartitioned = lib.partition (k: k.type == "gpg") publicKeys;
    gpgKeyring = runCommand "gpgKeyring" { buildInputs = [ gnupg ]; } ("gpg --no-default-keyring --homedir /build --keyring $out --fingerprint\n" + (lib.concatMapStrings (k: "gpg --homedir /build --no-default-keyring --keyring $out --import ${k.key}\n") keysPartitioned.right));
    gpgWithKeys = writeShellApplication {
      name = "gpgWithKeys";
      runtimeInputs = [ gnupg ];
      text = ''
        gpg --always-trust --homedir /build --no-default-keyring --keyring ${gpgKeyring} "$@"
      '';
    };
    allowedSignersFile = writeText "allowed signers" (lib.concatMapStrings (k: "* ${k.type} ${k.key}\n") keysPartitioned.wrong);
  in
  runCommand name
  {
    buildInputs = [ git openssh gpgWithKeys ];
    inherit verifyCommit verifyTag leaveDotGit;
  } ''
    if test "$verifyCommit" == 1; then
        git \
          -c gpg.ssh.allowedSignersFile="${allowedSignersFile}" \
          -c safe.directory='*' \
          -c gpg.program="gpgWithKeys" \
          -C "${fetchresult}" \
          verify-commit ${rev}
    fi
    if test "$verifyTag" == 1; then
        git \
          -c gpg.ssh.allowedSignersFile="${allowedSignersFile}" \
          -c safe.directory='*' \
          -c gpg.program="gpgWithKeys" \
          -C "${fetchresult}" \
          verify-tag ${rev}
    fi
    if test "$leaveDotGit" != 1; then
        cp -r --no-preserve=all "${fetchresult}" $out
        rm -rf "$out"/.git
    else
        ln "${fetchresult}" $out
    fi
  ''
)

