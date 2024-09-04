# zk-regex-circom

Circom circuits for regex verification in [zk-regex](https://github.com/zkemail/zk-regex/tree/main).
This package contains circom circuits and decomposed regex definitions for common regexes in `./circuits/common` folder.
 
## Note
Our `email_domain_regex.circom` circuit cannot capture an email address that contains "@" in the name part before the domain part, e.g., "alice@gmail.com@dummy.com", due to limitation of our circuit construction. For example, when "alice@gmail.com@dummy.com" is given, that circuit outputs not "dummy.com" but "gmail.com@dummy.com" as an exposed substring for the domain. However, an adversary cannot exploit this feature to expose a fake domain since the true domain at the end will also be revealed along with it.