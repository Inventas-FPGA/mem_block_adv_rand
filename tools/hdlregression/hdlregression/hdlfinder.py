#
# Copyright (c) 2022 by HDLRegression Authors.  All rights reserved.
# Licensed under the MIT License; you may not use this file except in compliance with the License.
# You may obtain a copy of the License at https://opensource.org/licenses/MIT.
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
# an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and limitations under the License.
#
# HDLRegression AND ANY PART THEREOF ARE PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
# WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS
# OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
# OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH UVVM OR THE USE OR OTHER DEALINGS IN HDLRegression.
#


import os
import fnmatch
import glob
from .report.logger import Logger


class HDLFinder(object):
    """
    Class for locating files and creating hdlregression file objects.
    """

    _WILDCARDS = ("*", "?", "[")

    def __init__(self, project, filename=None):
        self.logger = Logger(name=__name__, project=project)
        self.project = project
        self.file_list = []
        self._seen = set()

        if filename:
            if os.path.isdir(filename):
                self.logger.warning("Filename is directory: %s" % filename)
            else:
                self.find_files(filename)

    def _has_wildcards(self, path):
        for wildcard in self._WILDCARDS:
            if wildcard in path:
                return True
        return False

    def _is_dir(self, p):
        try:
            return os.path.isdir(p)
        except OSError:
            return False

    def _iter_candidates(self, directory, recursive):
        """
        Yield (root, filename) pairs either from a single directory
        or by walking the directory tree, depending on 'recursive'.
        """
        if recursive:
            for root, _, files in os.walk(directory):
                for f in files:
                    yield root, f
        else:
            try:
                files = os.listdir(directory)
            except OSError:
                return

            files.sort()
            for f in files:
                yield directory, f

    def find_files(self, filename, recursive=False):
        """
        Find all files matching 'filename' (case-insensitive).
        Adds matched file paths to self.file_list if not already present.
        Supports wildcards in directory segments.
        """
        script_path = (
            self.project.settings.get_script_path()
            if not self.project.settings.get_is_gui_mode()
            else ""
        )

        # Normalize separators to current OS (accept / and \)
        filename = filename.replace("\\", os.sep).replace("/", os.sep)

        search_path = os.path.normpath(os.path.join(script_path, filename))
        search_dir = os.path.dirname(search_path) or "."
        search_pattern = os.path.basename(search_path)

        # Resolve directories to search
        if self._has_wildcards(search_dir):
            dirs = []
            for d in glob.glob(search_dir):
                if self._is_dir(d):
                    dirs.append(d)

            if not dirs:
                return

            dirs.sort()

        # No wildcards
        else:
            if not self._is_dir(search_dir):
                return
            dirs = [search_dir]

        pattern = search_pattern.lower()

        # Search each resolved directory
        for dir in dirs:
            try:
                for root, name in self._iter_candidates(dir, recursive):
                    if fnmatch.fnmatch(name.lower(), pattern):
                        full_path = os.path.join(root, name)
                        if full_path not in self._seen:
                            self._seen.add(full_path)
                            self.file_list.append(full_path)
            except OSError as e:
                try:
                    self.logger.debug("Finder failed in '{}': {}".format(dir, e))
                except Exception:
                    pass

    def get_file_list(self):
        """
        Return list of all files found.
        """
        return self.file_list
