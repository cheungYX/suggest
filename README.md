# suggest
a simple program for suggest or spellcheck keyword use trie tree

# How to use
* install depends gem
```
gem install natto
gem install romaji
gem install activesupport
```
* install trie suggest
```
gem install trie_suggest
```


# Depends
* natto
* romaji

# Trouble Shooting
* MECAB_PATH error
  ```
  LoadError: Please set MECAB_PATH to the full path to libmecab.dylib
  ```

  ```
  sudo find /usr/ -name "libmecab*"
  export MECAB_PATH=you_libmecab_path
  ```

*  Function 'mecab_model_new2' not found
  ```
  brew install mecab
  brew install mecab-ipadic
  ```
