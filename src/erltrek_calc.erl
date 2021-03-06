%%% -------------------------------------------------------------------
%%% Erltrek ("this software") is covered under the BSD 3-clause
%%% license.
%%%
%%% This product includes software developed by the University of
%%% California, Berkeley and its contributors.
%%%
%%% Copyright (c) 2014 Kenji Rikitake. All rights reserved.
%%%
%%% Redistribution and use in source and binary forms, with or without
%%% modification, are permitted provided that the following conditions
%%% are met:
%%%
%%% * Redistributions of source code must retain the above copyright
%%%   notice, this list of conditions and the following disclaimer.
%%%
%%% * Redistributions in binary form must reproduce the above
%%%   copyright notice, this list of conditions and the following
%%%   disclaimer in the documentation and/or other materials provided
%%%   with the distribution.
%%%
%%% * Neither the name of Kenji Rikitake, k2r.org, nor the names of
%%%   its contributors may be used to endorse or promote products
%%%   derived from this software without specific prior written
%%%   permission.
%%%
%%% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND
%%% CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
%%% INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
%%% MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
%%% DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS
%%% BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
%%% EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
%%% TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
%%% DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
%%% ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR
%%% TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF
%%% THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
%%% SUCH DAMAGE.
%%%
%%% This software incorporates portions of the BSD Star Trek source
%%% code, distributed under the following license:
%%%
%%% Copyright (c) 1980, 1993
%%%      The Regents of the University of California.
%%%      All rights reserved.
%%%
%%% Redistribution and use in source and binary forms, with or without
%%% modification, are permitted provided that the following conditions
%%% are met:
%%% 1. Redistributions of source code must retain the above copyright
%%%    notice, this list of conditions and the following disclaimer.
%%% 2. Redistributions in binary form must reproduce the above
%%%    copyright notice, this list of conditions and the following
%%%    disclaimer in the documentation and/or other materials provided
%%%    with the distribution.
%%% 3. All advertising materials mentioning features or use of this
%%%    software must display the following acknowledgement:
%%%      This product includes software developed by the University of
%%%      California, Berkeley and its contributors.
%%% 4. Neither the name of the University nor the names of its
%%%    contributors may be used to endorse or promote products derived
%%%    from this software without specific prior written permission.
%%%
%%% THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS
%%% IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
%%% LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
%%% FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE
%%% REGENTS OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
%%% INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
%%% (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
%%% SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
%%% HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
%%% CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
%%% OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
%%% EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
%%%
%%% [End of LICENSE]
%%% --------------------------------------------------------------------

-module(erltrek_calc).

-export([
         course_distance/4,
         destination/4,
         in_quadrant/1,
         in_quadrant/2,
         in_quadxy/1,
         in_sector/1,
         in_sector/2,
         in_sectxy/1,
         sector_course/2,
         sector_course_distance/2,
         sector_distance/2,
         quadxy_index/1,
         sectxy_index/1,
         index_quadxy/1,
         index_sectxy/1,
         galaxy_to_quadsect/1,
         quadsect_to_galaxy/1
        ]).

-include("erltrek.hrl").

%% check inside the quadrant

-spec in_quadrant(quadcoord()) -> boolean().

in_quadrant(X) -> (X >= 0) andalso (X < ?NQUADS).

-spec in_quadrant(quadcoord(), quadcoord()) -> boolean().

in_quadrant(X, Y) -> in_quadrant(X) andalso in_quadrant(Y).

-spec in_quadxy(#quadxy{}) -> boolean().

in_quadxy(#quadxy{ x=X, y=Y }) -> in_quadrant(X, Y).

%% check inside the sector

-spec in_sector(sectcoord()) -> boolean().

in_sector(X) -> (X >= 0) andalso (X < ?NSECTS).

-spec in_sector(sectcoord(), sectcoord()) -> boolean().

in_sector(X, Y) -> in_sector(X) andalso in_sector(Y).

-spec in_sectxy(#sectxy{}) -> boolean().

in_sectxy(#sectxy{ x=X, y=Y }) -> in_sector(X, Y).

%% Calculate course and distance between two quad/sect coordinates
%% Input: source #quadxy, #sectxy, dest #quadxy, #sectxy
%% Output:
%%   difference of X,
%%   difference of Y,
%%   course (0-360 degrees, 0: -X direction, clockwise (e.g., 90: +Y direction)),
%%   distance (unit: sector, number of sectors for a quadrant = ?NSECTS )

-spec course_distance(#quadxy{}, #sectxy{}, #quadxy{}, #sectxy{}) ->
    {ok, integer(), integer(), float(), float()} | out_of_bound.

course_distance(SQC, SSC, DQC, DSC) ->
    case in_quadxy(SQC) andalso in_quadxy(DQC) andalso
        in_sectxy(SSC) andalso in_sectxy(DSC) of
        true ->
            DIFFX = ((DQC#quadxy.x * ?NSECTS) + DSC#sectxy.x) -
                    ((SQC#quadxy.x * ?NSECTS) + SSC#sectxy.x),
            DIFFY = ((DQC#quadxy.y * ?NSECTS) + DSC#sectxy.y) -
                    ((SQC#quadxy.y * ?NSECTS) + SSC#sectxy.y),
            CRAD = math:atan2(DIFFY, -DIFFX),
            CRAD2 = case CRAD < 0 of
                true -> (CRAD + (2 * math:pi()));
                false -> CRAD
            end,
            CDEG = CRAD2 * 180 / math:pi(),
            DISTSD = math:sqrt((DIFFX * DIFFX) + (DIFFY * DIFFY)),
            {ok, DIFFX, DIFFY, CDEG, DISTSD};
        false ->
            out_of_bound
    end.

%% Calculate the destination coordinate from given coordinate
%% and course (0-360 degrees)
%% and distance (unit: sector)
%% Input: source #quadxy, #sectxy, course, distance
%% Output:
%% destination #quadxy, #sectxy

-spec destination(#quadxy{}, #sectxy{}, float(), float()) ->
    {ok, #quadxy{}, #sectxy{}} | out_of_bound.

destination(SQC, SSC, COURSE, DIST) ->
    SX = (SQC#quadxy.x * ?NSECTS) + SSC#sectxy.x,
    SY = (SQC#quadxy.y * ?NSECTS) + SSC#sectxy.y,
    ANGLE = COURSE / 180 * math:pi(),
    DIFFX = DIST * -math:cos(ANGLE),
    DIFFY = DIST * math:sin(ANGLE),
    DESTX = trunc(SX + DIFFX + 0.5),
    DESTY = trunc(SY + DIFFY + 0.5),
    DESTQC = #quadxy{x = DESTX div ?NSECTS, y = DESTY div ?NSECTS},
    DESTSC = #sectxy{x = DESTX rem ?NSECTS, y = DESTY rem ?NSECTS},
    case in_quadxy(DESTQC) andalso in_sectxy(DESTSC) of
        true ->
            {ok, DESTQC, DESTSC};
        false ->
            out_of_bound
    end.

%% Calculate delta x and y between two coordinates

-spec sector_delta(XY, XY) -> {number(), number()} when XY :: #sectxy{} | #galaxy{}.
sector_delta(#sectxy{ x=SX, y=SY }, #sectxy{ x=DX, y=DY }) ->
    {DX - SX, DY - SY};
sector_delta(#galaxy{ x=SX, y=SY }, #galaxy{ x=DX, y=DY }) ->
    {DX - SX, DY - SY}.


%% Calculate course and distance between two sectors
%% course (0-360 degrees, 0: -X direction, clockwise (e.g., 90: +Y direction)),

-spec sector_course_distance(XY, XY) -> {float(), float()} when XY :: #sectxy{} | #galaxy{}.

sector_course_distance(SC, DC) ->
    Delta = sector_delta(SC, DC),
    {sector_course(Delta), sector_distance(Delta)}.

%% Calculate course between two sectors

-spec sector_course(XY, XY) -> float() when XY :: #sectxy{} | #galaxy{}.

sector_course(SC, DC) ->
    sector_course(sector_delta(SC, DC)).

-spec sector_course({number(), number()}) -> float().
sector_course({DX, DY}) ->
    CRAD = math:atan2(DY, -DX),
    CRAD2 = case CRAD < 0 of
        true -> (CRAD + (2 * math:pi()));
        false -> CRAD
    end,
    CRAD2 * 180 / math:pi().


%% Calculate distance between two sectors

-spec sector_distance(XY, XY) -> float() when XY :: #sectxy{} | #galaxy{}.

sector_distance(SC, DC) ->
    sector_distance(sector_delta(SC, DC)).

-spec sector_distance({number(), number()}) -> float().
sector_distance({DX, DY}) ->
    math:sqrt((DX*DX) + (DY*DY)).

%% convert quadrant coordinate record to Quad array position

-spec quadxy_index(#quadxy{}) -> non_neg_integer().

quadxy_index(QC) ->
    (QC#quadxy.x * ?NQUADS) + QC#quadxy.y.

%% convert sector coordinate record to Sect array position

-spec sectxy_index(#sectxy{}) -> non_neg_integer().

sectxy_index(QC) ->
    (QC#sectxy.x * ?NSECTS) + QC#sectxy.y.

%% convert quadrant array index to coordinate

-spec index_quadxy(non_neg_integer()) -> #quadxy{}.

index_quadxy(QI) when is_integer(QI), QI >= 0 ->
    %% make the index wrap in case it goes out of bounds
    B = QI rem (?NQUADS * ?NQUADS),
    #quadxy{ x = B div ?NQUADS, y = B rem ?NQUADS }.

%% convert sector array index to coordinate

-spec index_sectxy(non_neg_integer()) -> #sectxy{}.

index_sectxy(SI) when is_integer(SI), SI >= 0 ->
    %% make the index wrap in case it goes out of bounds
    B = SI rem (?NSECTS * ?NSECTS),
    #sectxy{ x = B div ?NSECTS, y = B rem ?NSECTS }.

%% galaxy coordinate conversion

-spec galaxy_to_quadsect(#galaxy{}) -> {#quadxy{}, #sectxy{}}.

galaxy_to_quadsect(#galaxy{ x=GXf, y=GYf }) ->
    GX = trunc(GXf), GY = trunc(GYf),
    {#quadxy{ x=GX div ?NSECTS, y=GY div ?NSECTS},
     #sectxy{ x=GX rem ?NSECTS, y=GY rem ?NSECTS}}.

-spec quadsect_to_galaxy({#quadxy{}, #sectxy{}}) -> #galaxy{}.

quadsect_to_galaxy({#quadxy{ x=QX, y=QY }, #sectxy{ x=SX, y=SY }}) ->
    #galaxy{ x = (QX * ?NSECTS) + SX + 0.5, y = (QY * ?NSECTS) + SY + 0.5}.
