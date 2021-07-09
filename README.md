## Usage
Configures SSHD to pull an authorized keys list from a central server, via the `AuthorizedKeysCommand` directive.
Intended be used in tandem with [Gravitas-GM/key-manager](https://github.com/Gravitas-GM/key-manager).

```shell
$ git clone https://github.com/Gravitas-GM/key-manager-client.git
$ sudo ./key-manager-client/install.sh USERNAME
```

Where `USERNAME` is the name of the user that should be allowed SSH access via the keys provided by the key server. At
the moment, only one user is allowed to retrieve their keys this way.

