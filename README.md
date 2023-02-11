# zk-regex

A library to do regex verification in circom, adapted from the original zk-email. Hopefully will add halo2 soon as well.

```
yarn install
yarn compile "abc (a|b|c)+"
```

The compilation command generates a circom file at build/compiled.circom. This code is a JS adaptation of the Python regex-to-circom work done at https://github.com/zk-email-verify/zk-email-verify/tree/main/regex_to_circom .
