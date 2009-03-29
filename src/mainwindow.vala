/* mainwindow.vala
 *
 * Copyright (C) 2009  Igalia, S.L.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Author:
 * 	Igalia, S.L. <info@igalia.com>
 */

using GLib;
using Gtk;

public class Fgtw.MainWindow : Window {
	private TextBuffer text_buffer;
	private string filename;

	public MainWindow () {
		title = "fgtw";
	}

	construct {
		set_default_size (600, 400);

		destroy += Gtk.main_quit;

		var vbox = new VBox (false, 0);
		add (vbox);
		vbox.show ();

		var toolbar = new Toolbar ();
		vbox.pack_start (toolbar, false, false, 0);
		toolbar.show ();

		var button = new ToolButton.from_stock (Gtk.STOCK_SAVE);
		toolbar.insert (button, -1);
		button.is_important = true;
		button.clicked += on_save_clicked;
		button.show ();

		var scrolled_window = new ScrolledWindow (null, null);
		vbox.pack_start (scrolled_window, true, true, 0);
		scrolled_window.hscrollbar_policy = PolicyType.AUTOMATIC;
		scrolled_window.vscrollbar_policy = PolicyType.AUTOMATIC;
		scrolled_window.show ();

		text_buffer = new TextBuffer (null);

		var text_view = new TextView.with_buffer (text_buffer);
		scrolled_window.add (text_view);
		text_view.show ();
	}

	public void run () {
		show ();

		Gtk.main ();
	}

	private void on_save_clicked (ToolButton button) {
		if (filename == null) {
			var dialog = new FileChooserDialog (_("Save File"), this, FileChooserAction.SAVE,
				Gtk.STOCK_CANCEL, ResponseType.CANCEL,
				Gtk.STOCK_SAVE, ResponseType.ACCEPT);
			dialog.set_do_overwrite_confirmation (true);
			if (dialog.run () == ResponseType.ACCEPT) {
				filename = dialog.get_filename ();
			}

			dialog.destroy ();
			if (filename == null) {
				return;
			}
		}

		try {
			TextIter start_iter, end_iter;
			text_buffer.get_bounds (out start_iter, out end_iter);
			string text = text_buffer.get_text (start_iter, end_iter, true);
			FileUtils.set_contents (filename, text, -1);
		} catch (FileError e) {
			critical ("Error while trying to save file: %s", e.message);
			filename = null;
		}

	}

	static int main (string[] args) {
		Gtk.init (ref args);

		var window = new MainWindow ();
		window.run ();
		return 0;
	}

}
