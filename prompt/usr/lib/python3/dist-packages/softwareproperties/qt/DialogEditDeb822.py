#  Copyright (c) 2024 Simon Quigley <tsimonq2@ubuntu.com>
#
#  This program is free software; you can redistribute it and/or
#  modify it under the terms of the GNU General Public License as
#  published by the Free Software Foundation; either version 2 of the
#  License, or (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307
#  USA

from PyQt6.QtWidgets import (QDialog, QLineEdit, QPushButton, QVBoxLayout, QHBoxLayout, QLabel, QGridLayout, QWidget)
from PyQt6 import QtWidgets, uic
from aptsources.sourceslist import Deb822SourceEntry

class CustomSourceEntryField(QWidget):
    def __init__(self, dialog, key=None, value=None):
        super().__init__()

        self.dialog = dialog
        layout = QGridLayout(self)

        self.entry_key = QLineEdit(self)
        self.entry_key.setPlaceholderText("Key")
        self.entry_val = QLineEdit(self)
        self.entry_val.setPlaceholderText("Value")
        self.button_delete = QPushButton("Delete", self)

        if key is not None:
            self.entry_key.setText(key)

        if value is not None:
            self.entry_val.setText(value)

        self.entry_key.setCursorPosition(0)
        self.entry_val.setCursorPosition(0)

        layout.addWidget(self.entry_key, 0, 0)
        layout.addWidget(self.entry_val, 0, 1)
        layout.addWidget(self.button_delete, 0, 2)

        self.button_delete.clicked.connect(self.delete_field)

    def delete_field(self):
        self.setParent(None)
        self.deleteLater()

    def get_key(self):
        return self.entry_key.text()

    def get_val(self):
        return self.entry_val.text()


class DialogEditDeb822(QDialog):
    def __init__(self, parent, sourceslist, source_entry, datadir):
        super().__init__(parent)

        uic.loadUi("%s/designer/dialog_editdeb822.ui" % datadir, self)

        self.sourceslist = sourceslist
        self.source_entry = source_entry
        self.new_source_entry = None
        self.entry_types = self.findChild(QLineEdit, "entry_types")
        self.entry_uris = self.findChild(QLineEdit, "entry_uris")
        self.entry_suites = self.findChild(QLineEdit, "entry_suites")
        self.entry_comps = self.findChild(QLineEdit, "entry_comps")
        self.entry_comment = self.findChild(QLineEdit, "entry_comment")
        self.button_add_field = self.findChild(QPushButton, "add_button")
        self.button_box = self.findChild(QtWidgets.QDialogButtonBox, "buttonBox")

        self.additional_fields_layout = self.findChild(QGridLayout, "additional_sources_layout")
        self.populate_with_existing_source_entry()

        self.button_add_field.clicked.connect(self.create_custom_source_entry)

    def populate_with_existing_source_entry(self):
        self.entry_types.setText(" ".join(self.source_entry.types))
        self.entry_types.setCursorPosition(0)
        self.entry_uris.setText(" ".join(self.source_entry.uris))
        self.entry_uris.setCursorPosition(0)
        self.entry_suites.setText(" ".join(self.source_entry.suites))
        self.entry_suites.setCursorPosition(0)
        self.entry_comps.setText(" ".join(self.source_entry.comps))
        self.entry_comps.setCursorPosition(0)
        self.entry_comment.setText(self.source_entry.comment.rstrip())
        self.entry_comment.setCursorPosition(0)

        for key, value in self.source_entry.section.tags.items():
            if key not in ["Types", "URIs", "Suites", "Components"]:
                self.append_custom_source_entry_field(key=key, value=value)

    def append_custom_source_entry_field(self, key=None, value=None):
        field = CustomSourceEntryField(self, key, value)
        self.additional_fields_layout.addWidget(field)

    def create_custom_source_entry(self):
        self.append_custom_source_entry_field()

    def get_custom_source_entry_fields(self):
        return [self.additional_fields_layout.itemAt(i).widget() for i in range(self.additional_fields_layout.count())]

    def is_current_input_valid(self):
        if "" in (self.entry_types.text(), self.entry_uris.text(), self.entry_suites.text(), self.entry_comps.text()):
            return False

        for field in self.get_custom_source_entry_fields():
            if "" in (field.get_key(), field.get_val()):
                return False
        return True

    def source_entry_from_input(self):
        source_entry = Deb822SourceEntry(None, self.source_entry.file)

        source_entry.types = self.entry_types.text().split()
        source_entry.uris = self.entry_uris.text().split()
        source_entry.suites = self.entry_suites.text().split()
        source_entry.comps = self.entry_comps.text().split()
        source_entry.comment = self.entry_comment.text()

        for field in self.get_custom_source_entry_fields():
            source_entry.section[field.get_key()] = field.get_val()

        return source_entry

    def run(self):
        res = self.exec()
        if res == QtWidgets.QDialog.DialogCode.Accepted:
            self.new_source_entry = self.source_entry_from_input()

        self.hide()
        return res
