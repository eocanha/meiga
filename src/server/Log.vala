/* Meiga - Lightweight and easy to use web file server for your desktop
 *
 * Copyright (C) 2009 Igalia, S.L.
 *
 * Authors:
 *
 * Igalia, S.L. <info@igalia.com>
 * Enrique Ocaña González <eocanha@igalia.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

public class Log : GLib.Object {

  private PtrArray lines;
  private uint history_offset;
  private uint purge_trigger;

  public signal void changed();

  /** Max number of log lines to be recorded */
  public uint history_limit { get; set; default=1024; }

  /** Each how many log lines the history_limit must be enforced */
  public uint history_hysteresis { get; set; default=32; }

  public Log() {
	lines = new PtrArray();
	history_offset = 0;
	purge_trigger = 0;
  }

  /** Logs a line of text */
  public void log(string msg) {
	// Workaround for memory management problems
	string *s = "%s".printf(msg);
	lines.add(s);
	purge_trigger++;
	// If the array grows larger than the history_limit, forget the
	// first items. We only check this every "history_hysteresis"
	// insertions.
	if (purge_trigger>history_hysteresis && lines.len>history_limit) {
	  history_offset += lines.len-history_limit;
	  // Workaround for memory management problems. Memory freeing
	  for (uint i=0; i<lines.len-history_limit; i++) {
		delete lines.pdata[i];
	  }
	  lines.remove_range(0,lines.len-history_limit);
	  purge_trigger = 0;
	}

	// Notify observers
	changed();
  }

  /**
   * Gets stored log lines from the start index to the end of the log.
   * Some lines may have been lost. In that case the set returned will
   * start in the first recorded line.
   */
  public string get_pending(uint start) {
	uint i0 = (start<history_offset)?history_offset:start;
	StringBuilder result = new StringBuilder();
	for (uint i=i0-history_offset; i<lines.len; i++) {
	  string *line = lines.pdata[i];
	  result.append(line);
	  result.append("\n");
	}
	return result.str;
  }

}
