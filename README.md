# pom.xml Dependencies Updater (pomxml-dep-update)

If there is a newer version of the dependency in pom.xml, rewrite it to the latest version.

## Attention

This action may cause destructive changes to the existing file (`pom.xml`).

## Action Inputs

- `pom-path`: Path to `pom.xml` (e.g, `pom.xml`)
- `ignore-packages`: The packages that will not be updated, Comma separated (e.g, `com.tomacheese.abc,com.tomacheese.def`)

## Example

```yml
- name: pom.xml Dependencies Updater
  uses: book000/pomxml-dep-update@v1.0.1
  with:
    pom-path: pom.xml
    ignore-packages: com.tomacheese.abc,com.tomacheese.def
```
