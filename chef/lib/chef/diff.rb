require 'chef/mixin/shell_out'

class Chef

  # Generates file diffs.
  #--
  # TODO/BUG:
  # This is a quick hack. The final implementation should do the following:
  # * Support a max file size above which diffs won't be attempted.
  # * Support a max diff size above which results will be thrown out.
  # * implement diffs in a way that will be performant and not depend on the diff(1) program.
  #   Xdiff looks pretty hot for this: http://XMailServer.Org/xdiff.html
  class Diff
    include Mixin::ShellOut

    def initialize(old_file_path, new_file_path)
      @old_file_path, @new_file_path = old_file_path, new_file_path
    end

    def diff
      shell_out!("diff -N -U 3 #{@old_file_path} #{@new_file_path}", :returns => [0,1]).stdout
    end
  end
end
