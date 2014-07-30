function restore_backups_if_needed() {
  if [ $always_build_deps != true ]; then
    if [ -d $(mix_backup_path) ]; then
      cp -R $(mix_backup_path) ${HOME}/.mix
    fi
  fi

  if [ $erlang_changed != true ] && \
     [ $elixir_changed != true ] && \
     [ $rebar_changed != true ]  && \
     [ $always_build_deps != true ];
  then

    if [ -d $(deps_backup_path) ]; then
      cp -R $(deps_backup_path) ${build_path}/deps
    fi

    if [ -d $(build_backup_path) ]; then
      cp -R $(build_backup_path) ${build_path}/_build
    fi

  fi
}


function copy_hex() {
  mkdir -p ${build_path}/.mix/archives
  cp ${HOME}/.mix/hex.ets ${build_path}/.mix/
  cp ${HOME}/.mix/archives/hex.ez ${build_path}/.mix/archives
}


function app_dependencies() {
  local git_dir_value=$GIT_DIR

  # Enter build dir to perform app-related actions
  cd $build_path

  # Unset this var so that if the parent dir is a git repo, it isn't detected
  # And all git operations are performed on the respective repos
  unset GIT_DIR

  output_section "Fetching app dependencies with mix"
  mix deps.get --only prod || exit 1

  output_section "Compiling app dependencies"
  mix deps.compile || exit 1

  export GIT_DIR=$git_dir_value
  cd - > /dev/null
}


function backup_deps_and_build_if_needed() {
  if [ $always_build_deps != true ]; then
    # Delete the previous backups
    rm -rf $(deps_backup_path) $(build_backup_path)

    cp -R ${HOME}/.mix $(mix_backup_path)
    cp -R ${build_path}/deps $(deps_backup_path)
    cp -R ${build_path}/_build $(build_backup_path)
  fi
}


function compile_app() {
  local git_dir_value=$GIT_DIR
  unset GIT_DIR

  cd $build_path
  output_section "Compiling the app"
  mix compile || exit 1
  mix compile.protocols || exit 1

  export GIT_DIR=$git_dir_value
  cd - > /dev/null
}


function write_profile_d_script() {
  output_section "Creating .profile.d with env vars"
  mkdir $build_path/.profile.d

  local export_line="export PATH=\$HOME/.platform_tools:\$HOME/.platform_tools/erlang/bin:\$HOME/.platform_tools/elixir/bin:\$PATH
                     export LC_CTYPE=en_US.utf8
                     export MIX_ENV=prod"
  echo $export_line >> $build_path/.profile.d/elixir_buildpack_paths.sh
}

export_env_dir() {
  whitelist_regex=${2:-''}
  blacklist_regex=${3:-'^(PATH|GIT_DIR|CPATH|CPPATH|LD_PRELOAD|LIBRARY_PATH)$'}
  if [ -d "$env_path" ]; then
    for e in $(ls $env_path); do
      echo "$e" | grep -E "$whitelist_regex" | grep -qvE "$blacklist_regex" &&
      export "$e=$(cat $env_path/$e)"
      :
    done
  fi
}
