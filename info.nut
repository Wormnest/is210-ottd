/*
 * 	This file is part of rocketAI.
 *
 *	rocketAI is free software: you can redistribute it and/or modify
 *	it under the terms of the GNU General Public License as published by
 *	the Free Software Foundation, either version 2 of the License, or
 *	(at your option) any later version.
 *
 *	rocketAI is distributed in the hope that it will be useful,
 *	but WITHOUT ANY WARRANTY; without even the implied warranty of
 *	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *	GNU General Public License for more details.
 *
 *	You should have received a copy of the GNU General Public License
 *	along with rocketAI.  If not, see <http://www.gnu.org/licenses/>.
*/


class rocketAI extends AIInfo {
  function GetAuthor()      { return "Team Rocket"; }
  function GetName()        { return "rocketAI"; }
  function GetDescription() { return "En AI basert på http://wiki.openttd.org/ og ConvoyAI"; }
  function GetVersion()     { return 1; }
  function GetDate()        { return "2009-11-26"; }
  function CreateInstance() { return "rocketAI"; }
  function GetShortName()   { return "trAI"; }
}
/* Tell the core we are an AI */
RegisterAI(rocketAI());