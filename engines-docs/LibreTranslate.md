# LibreTranslate

[Argos Translate](https://github.com/argosopentech/argos-translate) via the [LibreTranslate](https://github.com/LibreTranslate/LibreTranslate) frontend.

## Configuration

First, you have to obtain an API key from an LibreTranslate instance. Check out [how to manage API keys](https://github.com/LibreTranslate/LibreTranslate#manage-api-keys) if you decide to host your own instance.

After that, you should write the following into your `minetest.conf`, assuming you are using the official instance:

```conf
babelfish.engine = libretranslate
# Instance root URL and token seperated by a semicolon (;)
babelfish.key = https://libretranslate.com;xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

## Supported Languages

The list of supported languages depends on the instance. The list is fetched on each server restart.
