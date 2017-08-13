{Copyright (C) 2012-2017 Yevhen Loza

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see <http://www.gnu.org/licenses/>.}

{---------------------------------------------------------------------------}

{ this is an experimental "thrash" unit replacing the "suicide" of some
  objects + tries to make the process thread-safer.
  usage: thrash.add(some_object); to schedule it's safe freeing
  and use thrash.clear each time you need to clear it.}
unit decothrash;

{$INCLUDE compilerconfig.inc}
interface
uses SysUtils, fgl;

type TThrash = specialize TFPGObjectList<TObject>;

var Thrash: TThrash;

implementation

initialization
Thrash := TThrash.create(true);

finalization
FreeAndNil(Thrash);

end.
