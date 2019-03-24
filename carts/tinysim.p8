pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
-- tiny sim 0.90
-- @yellowbaron, 3d engine @freds72
-- 3d math portions from threejs

-- json globals
local _tok={
  ['true']=true,
  ['false']=false}
function nop() return true end
local _g={
  cls=cls,
  clip=clip,
  map=map,
  print=print,
  line=line,
  spr=spr,
  sspr=sspr,
  pset=pset,
  rect=rect,
  rectfill=rectfill}

-- json parser
-- from: https://gist.github.com/tylerneylon/59f4bcf316be525b30ab
local table_delims={['{']="}",['[']="]"}
local function match(s,tokens)
  for i=1,#tokens do
    if(s==sub(tokens,i,i)) return true
  end
  return false
end
local function skip_delim(str, pos, delim, err_if_missing)
if sub(str,pos,pos)!=delim then
  --if(err_if_missing) assert'delimiter missing'
  return pos,false
end
return pos+1,true
end

local function parse_str_val(str, pos, val)
  val=val or ''
  --[[
  if pos>#str then
    assert'end of input found while parsing string.'
  end
  ]]
  local c=sub(str,pos,pos)
  -- lookup global refs
if(c=='"') return _g[val] or val,pos+1
  return parse_str_val(str,pos+1,val..c)
end
local function parse_num_val(str,pos,val)
  val=val or ''
  --[[
  if pos>#str then
    assert'end of input found while parsing string.'
  end
  ]]
  local c=sub(str,pos,pos)
  -- support base 10, 16 and 2 numbers
  if(not match(c,"-xb0123456789abcdef.")) return tonum(val),pos
  return parse_num_val(str,pos+1,val..c)
end
-- public values and functions.

function json_parse(str, pos, end_delim)
  pos=pos or 1
  -- if(pos>#str) assert'reached unexpected end of input.'
  local first=sub(str,pos,pos)
  if match(first,"{[") then
    local obj,key,delim_found={},true,true
    pos+=1
    while true do
      key,pos=json_parse(str, pos, table_delims[first])
      if(key==nil) return obj,pos
      -- if not delim_found then assert'comma missing between table items.' end
      if first=="{" then
        pos=skip_delim(str,pos,':',true)  -- true -> error if missing.
        obj[key],pos=json_parse(str,pos)
      else
        add(obj,key)
      end
      pos,delim_found=skip_delim(str, pos, ',')
  end
  elseif first=='"' then
    -- parse a string (or a reference to a global object)
    return parse_str_val(str,pos+1)
  elseif match(first,"-0123456789") then
    -- parse a number.
    return parse_num_val(str, pos)
  elseif first==end_delim then  -- end of an object or array.
    return nil,pos+1
  else  -- parse true, false
    for lit_str,lit_val in pairs(_tok) do
      local lit_end=pos+#lit_str-1
      if sub(str,pos,lit_end)==lit_str then return lit_val,lit_end+1 end
    end
    -- assert'invalid json token'
  end
end

local world=json_parse'{"scenarios":[{"name":"visual approach","args":[-417,326.3,85,600,-1,0,25,112,3,2],"weather":1,"briefing":[{"fn":"print","args":["remain on runway axis. extend the\nflaps and keep speed at 65-70\nknots by using pitch and\nthrottle. at 50 feet, smoothly\nclose throttle and raise the\nnose to gently touch down\nbelow 65 knots.\ntoo easy? add some wind!",8,30,6]}]},{"name":"final approach","args":[-408.89,230.77,85,1000,1,0,75,112,3,2],"weather":2,"briefing":[{"fn":"print","args":["fly heading of approx. 085\nkeep localizer (  ) centered\n(the wind might push you away)\nmaintain 1000 ft\nintercept glide slope ( )\nreduce power and extend flaps\nstart 500 ft/min descent\nkeep localizer centered\nkeep glideslope centered\nat 200 ft reduce power & land",8,30,6]},{"fn":"spr","args":[20,71,36]},{"fn":"spr","args":[38,100,55]}]},{"name":"full approach","args":[-222.22,461.54,313,3000,0,0,91,112,1,2],"weather":3,"briefing":[{"fn":"print","args":["cross pco (  ) on heading 313\nintercept localizer (  )\nturn left heading 265\ndescend to 2000 ft\nturn right heading 310\nfly 1 minute\nturn left heading 130\nintercept localizer\nturn left heading 085\nfly final approach and land",8,30,6]},{"fn":"spr","args":[35,51,29]},{"fn":"spr","args":[20,91,36]}]},{"name":"engine failure!","args":[-422.2,408,85,500,10,0,0,65,3,2],"weather":1,"briefing":[{"fn":"print","args":["you have just taken off\nfrom tinyville for a trip\nto the beach, when the\nengine suddenly quits at\nonly 500 feet! make a steep\nturn back to airport while\nmaintaining best glide\nspeed (65 knots). can you\nmake it back? good luck!",8,30,6]}]},{"name":"unusual attitude","args":[-222.22,461.54,330,450,99,99,100,112,3,2],"weather":1,"briefing":[{"fn":"print","args":["while checking the map you did\nnot pay attention to your\nattitude. when you look up,\nthe airplane is out of control\nat low altitude. oops!\ncan you recover?\nhint: bank first, then pull up",8,30,6]}]},{"name":"free flight","args":[-422.2,384.6,85,0,0,0,0,0,5,2,true],"weather":1,"briefing":[{"fn":"print","args":["you are cleared for take-off\non runway 08 at tinyville.\napply full power and raise\nthe nose at 50-55 knots.\nhave fun!",8,30,6]}]}],"wx":[{"name":"clear, calm","dir":[0,0],"sky_gradient":[0,14,0,360,2,0,1440,1,0]},{"name":"clouds, breezy","dir":[60,10],"ceiling":500,"horiz":56,"sky_gradient":[0,213,-23131,500,5,0],"tex":{"x":0,"y":32},"light_ramp":68,"light_scale":0.125},{"name":"low clouds, stormy","dir":[10,20],"ceiling":200,"horiz":28,"sky_gradient":[0,5,0],"tex":{"x":64,"y":32},"light_ramp":68,"light_scale":0.08}],"db":[{"lat":-251.11,"lon":430.77,"name":"pco","type":"vor","nav":true},{"lat":-422.46,"lon":387.59,"name":"itn","type":"ils","angle":85},{"lat":-422.2,"lon":384.6,"name":"tny","type":"apt","angle":85,"nav":true},{"lat":-244,"lon":268.5,"name":"smallville","type":"cty"},{"lat":-66.67,"lon":153.85,"name":"smv","type":"apt","angle":40,"nav":true},{"lat":-177.78,"lon":246.15,"name":"wee","type":"vor","nav":true},{"lat":-70.17,"lon":531.28,"name":"pti","type":"apt","angle":170,"nav":true},{"lat":0,"lon":0,"name":"","type":"grnd"},{"lat":-169.64,"lon":100.27,"name":"mt. big","type":"mnt_big"},{"lat":-157.76,"lon":402.52,"name":"","type":"ship","angle":56}],"vspeeds":[{"ias":55,"s":40},{"ias":60,"s":56},{"ias":65,"s":41},{"ias":79,"s":57}],"hsic":[64,111],"bp":{"v":[[64,98],[64,102],[62,100],[66,100],[64,120],[64,124]],"e":[[1,2],[1,3],[1,4],[5,6]]},"nesw":[[64,99,52],[52,111,53],[64,123,36],[76,111,37]],"cdii":{"v":[[64,98],[64,102],[62,100],[66,100],[64,120],[64,124],[64,104],[64,118]],"e":[[1,2],[1,3],[1,4],[5,6],[7,8]]},"apsymbol":{"v":[[55,87],[61,87],[58,86],[58,91],[57,91],[59,91]],"e":[[1,2],[3,4],[5,6]]},"lcockpit":[{"fn":"map","args":[0,0,-4,26,17,3]},{"fn":"map","args":[0,3,-4,48,2,11]},{"fn":"spr","args":[18,71,120]},{"fn":"spr","args":[34,79,115]},{"fn":"rectfill","args":[107,121,127,127,0]},{"fn":"rectfill","args":[87,115,100,127,0]},{"fn":"spr","args":[35,79,122]}],"rcockpit":[{"fn":"clip","args":[]},{"fn":"map","args":[17,0,-4,26,27,3]},{"fn":"map","args":[32,3,116,50,2,10]},{"fn":"spr","args":[21,107,120]},{"fn":"spr","args":[42,115,120]},{"fn":"line","args":[4,36,4,42,0]}],"briefing":[{"fn":"print","args":["press ❎ to   fly",8,112,7]},{"fn":"spr","args":[2,54,112]},{"fn":"spr","args":[3,77,112]},{"fn":"print","args":["z: back to menu",8,119,6]}],"intro":[{"fn":"cls","args":[]},{"fn":"spr","args":[2,34,10]},{"fn":"spr","args":[3,78,10]},{"fn":"print","args":["tiny sim",44,10,7]},{"fn":"print","args":["the world\'s smallest flight sim",2,20,6]},{"fn":"print","args":["press ❎ for briefing",8,57,7]},{"fn":"print","args":["x/z: throttle",8,80,6]},{"fn":"print","args":["q:   toggle flaps",8,87]},{"fn":"print","args":["tab: toggle instruments / map",8,94]},{"fn":"print","args":["e:   cycle gps waypoint",8,101]},{"fn":"rect","args":[5,77,125,108,6]},{"fn":"print","args":["@yellowbaron | 3d by @freds72",7,123,6]}],"gs":[{"fn":"pset","args":[92,61,7]},{"fn":"pset","args":[92,66,7]},{"fn":"pset","args":[92,71,7]},{"fn":"pset","args":[92,76,7]},{"fn":"pset","args":[92,81,7]},{"fn":"line","args":[91,71,93,71,7]}]}'
-- dither pattern 4x4 kernel
local dither_pat=json_parse'[0xffff.8,0x7fff.8,0x7fdf.8,0x5fdf.8,0x5f5f.8,0x5b5f.8,0x5b5e.8,0x5a5e.8,0x5a5a.8,0x1a5a.8,0x1a4a.8,0x0a4a.8,0x0a0a.8,0x020a.8,0x0208.8,0x0000.8]'

--scenarios (name,lat,lon,hdg,alt,pitch,bank,throttle,tas,dto,nav1,onground)

--weather (name,wind,ceiling,bg color,sky gradient,light_ramp x offset, inverse light distance)

--airport and navaid database (rwy hdg < 180)

-- shortcuts
local scenarios,wx,db,hsic,bp,cdii,nesw,vspeeds,apsymbol=world.scenarios,world.wx,world.db,world.hsic,world.bp,world.cdii,world.nesw,world.vspeeds,world.apsymbol

--general settings and vars
palt(15,true)
palt(0,false)
local frame=0

-- scenario + weather selection
local scen,wnd=1,1

--3d
-- world axis
local v_fwd,v_right,v_up={0,0,1},{1,0,0},{0,1,0}

-- models & actors
local all_models,actors,stars,cam={},{},{}
-- sim + pilot pos (in camera space)
local pilot_pos,sim={0,0.037,0}

-- current texture location (32x32)
local tex_src

function _init()
 menu,item=1,0
 scen,wnd=1,1

 --3d
 cam=make_cam(64,12,64)

 -- reset actors & engine
 actors,sim={}
 for _,l in pairs(db) do
  -- registered model?
  if all_models[l.type] then
			add(actors,make_actor(l.type,{l.lat,0,l.lon},l.angle))
		end
	end
end

-- create a simulator entity from the given scenario
function make_sim(s)
  local brg,dist,crs,cdi={},{},0,0
  local rpm,vs,aoa,timer,flps,blag,plag,slag,relwind=2200,0,0,0,0,0,0,0

  -- plane pos/orientation
  local lat,lon,heading,alt,pitch,bank,throttle,tas,dto,nav1,onground=munpack(scenarios[s].args)
  -- safeguard
  assert(nav1,"missing scenario arg")

  if(pitch==99) bank,pitch=unusual()

  --instruments
  --ai
  local aic={64,71} --center
  local ai=json_parse'[[-87,72],[215,72],[64,-79],[64,223]]'
  local aipitch,aistep,aiwidth={60,141},10,8

  --inset map
  local mapc={22,111} --center
  local mapclr={apt=14,vor=12,ils=0,cty=5}

  local warn=function(y)
    local j=y>64 and -1 or 1
    for i=0,3 do
      local _y=y+i*aistep+pitch
      local x1,y1=rotatepoint({aipitch[1],_y},aic,-bank)
      local x2,y2=rotatepoint({aipitch[1]+aiwidth/2,_y+(aistep-2)*j},aic,-bank)
      local x3,y3=rotatepoint({aipitch[1]+aiwidth,_y},aic,-bank)
      line(x1,y1,x2,y2,8)
      line(x3,y3,x2,y2)
    end
  end

		-- engine sound
		sfx(2)
		sfx(7)

  return {
    -- pos and orientation
    get_pos=function()
      return {lat,alt/120,lon},make_m_from_euler(-pitch/360,heading/360-0.25,-bank/360)
    end,
    crashed=false,
    input=function()
      -- rpm
      --set throttle
      if btn(5) then --x
        throttle+=1.5
        blag=-3
      elseif btn(4) then --y
        throttle-=1.5
        blag=3
      end
      throttle=mid(throttle,0,100)
      --calculate rpm
      local maxrpm=2400
      if(alt>=2000) maxrpm=2456-0.028*alt
      targetrpm=throttle/100*(maxrpm-700)+700
      rpm+=(targetrpm-rpm)/20
      if(abs(targetrpm-rpm)>=30) plag=(targetrpm-rpm)/20
      rpm=max(rpm,700)

      -- pitch
      if btn(2) then -- dn
        plag=max(plag-2,-60)
        pitch-=0.25*cos(bank/360)
      elseif btn(3) and aoa<18 then -- up
        plag=min(plag+2,60)
        pitch+=0.35*cos(bank/360)
      elseif plag!=0 then
        pitch+=0.004*plag*cos(bank/360)
        plag-=plag/abs(plag)
      end
      pitch=mid(pitch,-45,45)

      if btn(0) then
        if onground and tas<30 then --nosewheel steering
          heading-=0.6
        else
          blag=max(blag-1,-50)
          bank-=1.8-tas/250
        end
      elseif btn(1) then
        if onground and tas<30 then
               heading+=0.6
            else
              blag=min(blag+1,50)
          bank+=1.8-tas/250
            end
      elseif blag!=0 then
        bank+=0.03*blag
        blag-=blag/abs(blag)
      end
      if (abs(bank)<4 and blag==0) bank/=1.1 --bank stability
      if(abs(bank)>20) pitch-=0.3*abs(sin(bank/360))
      if(abs(bank)>160) pitch-=0.15

						if(bank>180) bank-=360
      if(bank<-180) bank+=360
						
      -- flaps()
      if btnp(5,1) then --q
        flps=1-flps --toggle
        plag=flps==1 and 70 or -70
      end

      -- cycle gps navigation waypoint
      if btnp(2,1) then --e
        dto+=1
        if(dto==#db+1) dto=1
        while db[dto].nav!=true do
          dto+=1
          if(dto==#db+1) dto=1
        end
      end

      -- on ground check
      if onground then
        bank/=1.3 --level off on ground
        pitch=max(pitch)
      end
    end,
    update=function(self)
      -- calcalt
      local coeff=vs<0 and 74 or 88
      vs=tas*-sin((pitch-aoa)/360)*coeff
      if(alt==0) vs=max(vs)
      alt=max(alt+vs/1800)

      -- calcheading()
      if abs(bank)<=90 then heading+=bank*0.007
      else heading+=(180-abs(bank))*bank/abs(bank)*0.007 end
      heading=(heading+360)%360

      -- calcspeed()
      local targetspeed=38.67+rpm/30-3.8*pitch
      targetspeed=mid(targetspeed,-30,200)
      if(flps==1) targetspeed-=10
      if(onground) targetspeed-=40
      tas+=(targetspeed-tas)/250
      ias=tas/(1+alt/1000*0.02) --2% per 1000 ft

      -- calcaoa()
      if ias>=71.1 then
        aoa=13.2-0.12*ias
      elseif ias>=46.7 then
        aoa=26-0.3*ias
      else
        aoa=54-0.9*ias
      end
      aoa=max(aoa)
      -- calcwind()
      local wind=wx[wnd].dir
      relwind=heading-wind[1]
      relwind=(relwind+180)%360-180
      local relh,relc=-wind[2]*cos(relwind/360),wind[2]*sin(relwind/360)
      groundspeed=sqrt((tas/10+relh/10)^2+(relc/10)^2) --avoid tas^2 overflow
      groundspeed=ceil(10*groundspeed)
      local wca=onground and 0 or (atan2(tas+relh,relc)*360+180)%360-180
      -- actual 2d velocity direction
      track=heading+wca

      -- calcposition()
      local dx,dy=-groundspeed*sin(track/360)/2880,groundspeed*cos(track/360)/2880
      lon+=dx
      lat-=dy

      -- calcdistbrg()
      local j=1
      for _,l in pairs(db) do
        local dy,dx=-(l.lat-lat)*0.01,(l.lon-lon)*0.01 --avoid overflow
        brg[j]=90+(atan2(dx,dy)*360)-heading
        brg[j]-=flr(brg[j]/360)*360
        dist[j]=max(sqrt(dx*dx+dy*dy))*2.6667 --*100*16/600
        j+=1
      end

      -- stall()
      local critical=18+4*flps
      if aoa>=critical then
        slag,plag=45,0
        if(not onground) blag=-10
      end
      pitch-=slag*(onground and 0.003 or 0.008)
      if (slag>=1) slag-=1

      -- calcgs()
      local alpha=atan2(alt/6072,dist[nav1])*360-270
      gsy=mid(63+10/0.7*(alpha-3),50,74)

      -- calccdi()
      local cdangle=brg[nav1]-crs
      cdangle=(cdangle+360)%360
      if(cdangle>180) cdangle-=360
      if cdangle>90 then cdangle=180-cdangle --backcourse
      elseif cdangle<-90 then cdangle=-180-cdangle end
      cdi=mid(18/10*cdangle,-9,9) --5 deg full deflection

			   -- sfx mgt
      -- see: https://www.lexaloffle.com/bbs/?tid=2341
      -- pitch+shl(instr,6)+shl(vol,9)
      local p=(rpm-700)/1000 --original was 1400, renamed to p to avoid issue with airplane pitch
      local rpmvol=shl(band(0x7,2+2*p),9)
      -- sfx 2
      poke4(0x3288,bor(band(0x3f,7*p)+0x040+rpmvol,shr(band(0x3f,6*p)+0x040+rpmvol,16)))
      -- wind noise (> 120 knots relative speed)
      local wndvol=max(ias-120)/60 -- 180-120
      if wndvol>0 then
        -- convert to sfx volume
        wndvol=shl(band(0x7,7*wndvol),9)
        -- use it for 2 notes
        wndvol=bor(wndvol,shr(wndvol,16))
        local src=0x33dc -- sfx 7
        -- 2 notes/loop (eg 4 bytes)
        -- 32 notes total
        for k=1,16 do
         -- copy sound + adjust volume
         poke4(src,bor(band(peek4(src),0xf1ff.f1ff),wndvol))
         src+=4
        end
      end

      -- checklanded()
      -- map tile
      -- todo: boundary checks
      -- alternative: make the map boundaries a no fly zone!
      local mx,my=flr(16*lon/600)+46,flr(16*(600+lat)/600)+8
      local tile=fget(mget(mx,my))

      if(ias>180) make_msg("exceeded maximum speed\nreduce power & pull up!!!")
      --sfx(4)
      if alt<=0 and not onground then
        onground=true
        if tile==2 then -- water!
          make_msg("crashed into the ocean\nz: exit to menu",300)
          self.crashed=true
          -- todo: better splash sound?
          sfx(8)
        elseif vs>-300 and pitch>-0.5 and abs(bank)<5 then
          make_msg("good landing!")
          sfx(6) --rolling sound
        elseif vs>-1000 and pitch>-0.5 and abs(bank)<30 then
          make_msg("oops... hard landing")
          sfx(6) --rolling sound
        else
          make_msg("crash: collision with ground\nz: exit to menu",300)
          self.crashed=true
          sfx(3)
        end
      end
      if alt>0 and onground then
        onground=nil
        -- stop rolling sound
        sfx(6,-2)
      end
      -- no fly zone
      if tile==1 then
       make_msg("immediately leave this zone!\nyour license will be revoked")
       -- todo: fix sound
       sfx(9)
      end

      timer+=1/30
      -- flaps(): moved to input
      -- blackbox(): removed
    end,
    draw=function()
      if menu==0 then
        -- dispai()
        ai[1][2]=72+pitch
        ai[2][2]=72+pitch
        ai[3][2]=-80+pitch
        ai[4][2]=222+pitch
        local ax,ay=rotatepoint(ai[1],aic,-bank)
        local bx,by=rotatepoint(ai[2],aic,-bank)
        local cx,cy=rotatepoint(ai[3],aic,-bank)
        local dx,dy=rotatepoint(ai[4],aic,-bank)
        clip(10,36,118,96)
        trifill(ax,ay,bx,by,cx,cy,12)
        trifill(ax,ay,bx,by,dx,dy,4)
        line(ax,ay,bx,by,7) --horizon
        clip(35,44,55,43)
        for j=0,15 do
          local tmp=aipitch[2]-j*aistep+pitch
          local x1,y1=rotatepoint({aipitch[1],tmp},aic,-bank)
          local x2,y2=rotatepoint({aipitch[1]+aiwidth,tmp},aic,-bank)
          if(j!=7) line(x1,y1,x2,y2,7)
        end
        warn(-8)
        warn(110)
        clip()
        --transparency
        rectfillt(21,50,33,90)
        rectfillt(95,50,111,90)

        line(48,75,aic[1],aic[2],10) --aircraft
        line(80,75,aic[1],aic[2])
        line(40,71,45,71) --small horizon lines
        line(83,71,88,71)

        drawstatic(world.lcockpit)

        -- disphsi()
        --transparency
        circfillt(64,111,15.5)
        circ(64,111,8,7)
        spr(19,62,95) --tick mark
        --cardinal directions
        for _,l in pairs(nesw) do
          local x,y=rotatepoint(l,hsic,-heading)
          spr(l[3],x-1,y-1)
        end
        --bearing pointer
        polyliner(bp,hsic,brg[dto],12)
        --cdi
        crs=db[nav1].angle-heading
        cdii.v[7][1]=cdi+64
        cdii.v[8][1]=cdi+64
        polyliner(cdii,hsic,crs,11)
        spr(33,62,110) --heading plane symbol
        --dto bearing
        ?flr(brg[dto]+heading)%360,117,37,14

        -- disprpm()
        local drpm=ceil(rpm/10)*10
        color(drpm<=2000 and 7 or 11)
        if drpm>=1000 then
          ?sub(drpm,1,2),1,116
          ?sub(drpm,3,4),1,122
        else
          ?sub(drpm,1,1),5,116
          ?sub(drpm,2,3),1,122
        end
        spr(4,1,109-throttle/4.4)

        -- dispspeed()
        clip(22,50,32,41)
        local dy,n=ias*3,ias>20 and flr(ias/10) or 2
        for i=n,n+2 do
          local x=i*10>99 and 22 or 26
          ?i*10,x,70-(i*30)+dy,6
          line(31,72-(i*30)-15+dy,33,72-(i*30)-15+dy)
        end
        clip()
        -- red or black
        rectfill(21,68,33,74,ias>=163 and 8 or 0)
        rectfill(29,65,33,77)
        local y=ias-flr(ias/10)*10
        local y2,y3=ceil(y),(y*7)%7
        if ias>=20 then
          clip(30,65,3,13)
          ?y2%10,30,66+y3,7
          ?(y2-1)%10,30,72+y3
          ?(y2+1)%10,30,60+y3
          clip()
          local z=ias>=99.5 and 22 or 26
          -- ensure smooth transition to next ias
          ?flr((ias+0.5)/10),z,69
        else
          -- warn: minify bug
          ?'---',22,69,7
        end

        clip(34,50,8,41)
        for _,v in pairs(vspeeds) do
          spr(v.s,34,(ias-v.ias)*3+69)
        end
        clip()

        -- dispalt()
        clip(95,50,16,41)
        local dy,n=alt/5,alt>199 and flr(alt/100) or 2
        for i=n-2,n+2 do
            local x=i<100 and 96 or 92
            ?i*100,x,70-(i*20)+dy,6
            line(95,62-(i*20)+dy,97,62-(i*20)+dy,6)
        end
        clip()
        rectfill(95,68,111,74,0)
        rectfill(103,65,111,77)
        local y=alt/10-flr(alt/100)*10
        local y2,y3=ceil(y),(y*7)%7
        clip(104,65,7,13)
        ?(y2%10)..0,104,66+y3,7
        ?((y2-1)%10)..0,104,72+y3
        ?((y2+1)%10)..0,104,60+y3
        clip()
        local z=96
        if alt>=9995 then
          rectfill(91,68,94,74,0)
          z=92
        elseif alt<995 then
          z=100
        end
        if alt>=100 then
         ?flr((alt/10+0.5)/10),z,69,7
        end

        -- dispvs()
        local vsoffset=ceil(vs/100)
        vsoffset=mid(vsoffset,-19,21)
        rectfill(115,68-vsoffset,126,74-vsoffset,0)
        spr(23,112,68-vsoffset)
        if vsoffset!=0 then
         ?ceil(vs/100),115,69-vsoffset,7
        end

        -- dispheading()
        rectfill(57,88,71,94,0)
        pset(70,89,7)
        local hdg=ceil(heading)%360
        if hdg<10 then print("00"..hdg,58,89,7)
        elseif hdg<100 then print("0"..hdg,58,89,7)
        else
          ?hdg,58,89,7
        end

        -- old: disptime()
        disptime(timer,108,122)

								-- dispnav
        ?db[nav1].name,29,37,11
        dispdist(dist[dto],89,116,7)
        dispdist(dist[dto],88,37,14)
        ?db[dto].name,57,37,14
        ?db[dto].name,89,122,12

        -- dispmap()
        --based on 5nm/187.5 per 22px
        rectfill(11,97,33,119,0)
        local latmin,lonmin=lat+67.77, lon-93.75
        disppoint=function(p)
          --scale to map
          local mapx,mapy=11+22/187.5*(p.lon-lonmin),119-22/187.5*(-p.lat+latmin)
          local rotx,roty=rotatepoint({mapx,mapy},mapc,360-heading)
          return {rotx,roty}
        end
        for l in all(db) do
          local p=disppoint(l)
          if(checkonmap(p)) pset(p[1]+0.5,p[2],mapclr[l.type])
        end
        spr(33,20,110) --map plane symbol

        -- dispgs()
        if dist[nav1]<15 and alt<9995 then
        	rectfillt(91,58,93,84)
        	drawstatic(world.gs)
        	spr(38,91,gsy+8)
        end
        -- dispflaps()
        spr(flps==1 and 46 or 14,0,64,1,2)

        -- dispwind()
								local s
        if onground then
          s=127
        elseif relwind>=0 and relwind<90 then
          s=78
        elseif relwind<=0 and relwind>-90 then
          s=79
        elseif relwind>=90 and relwind<180 then
          s=94
        elseif relwind<=-90 and relwind>-180 then
          s=95
        end
							 spr(s,40,95)
      elseif menu==2 then
       drawmap(lat,lon,heading)

       -- clip included in rcockpit
       drawstatic(world.rcockpit)
       ?db[dto].name,17,37,14
       color(14)
       disptime(flr(dist[dto]/groundspeed*3600),94,37)
       ?groundspeed,54,37

      end     
    end
  }
end

function unusual()
  local sign=rnd()<0.5 and 1 or -1
  return (80-rnd(15))*sign,-45
end

function checkonmap(p)
  return p[1]>11 and p[1]<33 and p[2]>97 and p[2]<120
end

-- draw a rotated poly line
function polyliner(m,c,angle,col)
  color(col)
  -- edge pairs
  for _,l in pairs(m.e) do
    local x1,y1=rotatepoint(m.v[l[1]],c,angle)
    local x2,y2=rotatepoint(m.v[l[2]],c,angle)
    line(x1,y1,x2,y2)
  end
end

function rotatepoint(p,c,angle)
  local x,y=p[1]-c[1],p[2]-c[2]
  local cs,ss=cos(angle/360),sin(angle/360)
  return x*cs+y*ss+c[1],-x*ss+y*cs+c[2]
end

function dispdist(d,x,y,c)
  if d<10 then
    ?flr(d*10)/10,x,y,c
  else
    ?flr(d),x,y,c
  end
end

function disptime(t,x,y)
 local minutes=flr(t/60)
 local seconds=flr(t-minutes*60)
 if(minutes<10) minutes="0"..minutes
 if(seconds<10) seconds="0"..seconds
 ?minutes..":"..seconds,x,y
end

local message,message_t
function make_msg(msg,t)
  if(t==nil) t=60
  message,message_t=msg,t
end
function dispmessage()
  -- update & draw
  if message then
    message_t-=1
    if(message_t<0) message=nil sim.crashed=nil sfx(2) sfx(7) return

    local c = message_t%16<8 and 7 or 9
    rectfill(0,9,127,15,5)
    if(#message>20) rectfill(0,15,127,21,5)
		  ?message,10,10,c
	 end
end

function drawmenu()
  local c = frame%16<8 and 7 or 9

  drawstatic(world.intro)

  ?"flight:",8,37,item==0 and c or 7
  ?scenarios[scen].name,44,37,7
 	?"weather:",8,47,item==1 and c or 7
  ?wx[wnd].name,44,47,7

end

function drawmap(lat,lon,hdg)
 local dx,dy=scalemap(lon,lat)
 -- 58/87 are screen center coords for moving map
 clip(0,43,118,85)
 camera(-58+dx,-87+dy)
 map(34,0,-33,-128,47,31)

 for _,l in pairs(db) do
  local name,angle,x,y=l.name,l.angle,scalemap(l.lon,l.lat)
  x-=3 --correct for sprite size
  y-=3
  -- helper function (save tokens)
  local draw_ils=function(a,txt)
   local _x,_y=sin(a),cos(a)
   line(x+3,y+3,50*_x+x+3,50*_y+y+3,11)
   ?txt,62*_x+x+2,62*_y+y+3,7
  end
  if l.type=="vor" then
   spr(39,x,y)
   ?name,x+9,y+1,7
  elseif l.type=="ils" then
   draw_ils((angle-3)/360,"")
   draw_ils((angle+3)/360,name)
  elseif l.type=="apt" then
   if angle>=0 and angle<23 then spr(22,x,y)
   elseif angle>22 and angle<68 then spr(55,x,y)
   elseif angle>67 and angle<103 then spr(54,x,y)
   elseif angle>102 and angle<148 then spr(55,x-1,y,1,1,true)
   else spr(22,x,y) end
   ?name,x+9,y+1,7
  else
   -- city and mt. big
   spr(17,x,y)
   ?name,x-4*#name,y+1,5
  end
 end
 ?"tiny\nbay",265,-1,1
 camera()

 -- rotated plane
 polyliner(apsymbol,{58,87},hdg,7)
end

function scalemap(_x,_y)
  -- based on 16nm per 128px
  -- todo: remove 64/64 centering
  return 64+_x*0.2133,64+_y*0.2133
end

function drawbriefing()
  cls()
  ?"flight briefing:",8,10,6
  ?scenarios[scen].name,8,17,7

  --
  drawstatic(scenarios[scen].briefing)
		drawstatic(world.briefing)
end

-- execute the given draw commands from a table
function drawstatic(cmds)
  -- call native pico function from list of instructions
  for i=1,#cmds do
    local drawcmd=cmds[i]
    drawcmd.fn(munpack(drawcmd.args))
  end
end

function _update()
  frame+=1
  if menu==1 then --menu
    if btnp(5) then --x
      menu=3
    elseif btnp(3) then --down
      item+=1
      item%=2
      sfx(1)
    elseif btnp(2) then --up
      item-=1
      item%=2
      sfx(1)
    elseif btnp(1) then --right
      if item==0 then
        scen+=1
        if(scen==#scenarios+1) scen=1
        wnd=scenarios[scen].weather
      elseif item==1 then
        wnd+=1
        if(wnd==#wx+1) wnd=1
      end
      sfx(1)
    elseif btnp(0) then --left
      if item==0 then
        scen-=1
        if(scen==0) scen=#scenarios
        wnd=scenarios[scen].weather
      elseif item==1 then
        wnd-=1
        if(wnd==0) wnd=#wx
      end
      sfx(1)
    end
  elseif menu==3 then --briefing
    if btnp(5) then --x
      menu=0
      -- start game
      sim=make_sim(scen)
      -- ugly hack to get everything setup before _draw
      _update()
    elseif btnp(4) then --z
      _init()
    end
  else
   if(not sim.crashed) sim:input() sim:update()
   if(sim.crashed) sfx(2,-2) sfx(7,-2) sfx(6,-2) --todo: windvol=0
   if(sim.crashed and btn(4)) make_msg() menu=1

	  -- update cam
	  cam:track(sim:get_pos())

			-- switch l/r cockpit
   if btnp(4,1) then --tab
    menu=menu==0 and 2 or 0
   	-- offset pilot pos when looking right
   	pilot_pos[1]=menu==0 and 0 or 0.03
   end
  end
 -- pause menu
 menuitem(1, "back to sim menu", function() menu=1 sfx(-1) end)
end

function _draw()
  if menu==1 then
    drawmenu()
	 elseif menu==3 then
	  drawbriefing()
	 else
	  cls()
 		-- 3d
 		local weather=wx[wnd]
	  draw_ground(weather)
	  zbuf_draw(weather.horiz)
  	draw_clouds(weather)

   sim:draw()

   -- perf monitor!
   --[[
   local cpu=(flr(1000*stat(1))/10).."%"
   ?cpu,2,3,2
   ?cpu,2,2,7
   ]]
   end
  dispmessage()
end

-->8
-- 3d engine @freds72

-- https://github.com/morgan3d/misc/tree/master/p8sort
function sort(data)
 for num_sorted=1,#data-1 do
  local new_val=data[num_sorted+1]
  local new_val_key,i=new_val.key,num_sorted+1

  while i>1 and new_val_key>data[i-1].key do
   data[i]=data[i-1]
   i-=1
  end
  data[i]=new_val
 end
end

-- light blooms
-- note: cannot be packed into gfx, takes too much space
-- y=0
local light_shades={}
function unpack_ramp(x)
 local shades={}
  -- brightness pairs
	for i=0,15 do
		for j=0,15 do
			shades[i+16*j]=sget(x,i)+16*sget(x,j)
	 end
	end
	return shades
end

for c=0,15 do
 -- set base color for black + dark blue
 local hc=sget(72,c)
 sset(74,0,hc)
 sset(74,1,hc)
	light_shades[c]=unpack_ramp(74)
end

local znear,clipplanes=0.25,json_parse'[[0,0,1,8],[0.707,0,-0.707,0.1767],[-0.707,0,-0.707,0.1767],[0,0.707,-0.707,0.1767],[0,-0.707,-0.707,0.1767],[0,0,-1,-0.25]]'
local clipplanes_simple=json_parse'[[0,0,1,8],[0,0,-1,-0.25]]'

-- zbuffer (kind of)
function zbuf_draw(zfar)
	local objs={}

	for _,d in pairs(actors) do
  -- todo: cull objects too far
		collect_drawables(d.model,d.m,d.pos,zfar,objs)
	end

	-- z-sorting
	sort(objs)

 -- actual draw
	for i=1,#objs do
		local d=objs[i]
  if d.kind==3 then
			project_poly(d.v,d.c)
	 elseif d.y<40 then -- no need to draw outside of screen
   circfillt(d.x,d.y,d.r,light_shades[d.c])
  end
 end
end

function lerp(a,b,t)
	return a*(1-t)+b*t
end

function make_v(a,b)
	return {
		b[1]-a[1],
		b[2]-a[2],
		b[3]-a[3]}
end
function v_clone(v)
	return {v[1],v[2],v[3]}
end
function v_dot(a,b)
	return a[1]*b[1]+a[2]*b[2]+a[3]*b[3]
end
function v_scale(v,scale)
	v[1]*=scale
	v[2]*=scale
	v[3]*=scale
end
function v_add(v,dv,scale)
	scale=scale or 1
	v[1]+=scale*dv[1]
	v[2]+=scale*dv[2]
	v[3]+=scale*dv[3]
end

-- matrix functions
function m_x_v(m,v)
	local x,y,z=v[1],v[2],v[3]
	v[1],v[2],v[3]=m[1]*x+m[5]*y+m[9]*z+m[13],m[2]*x+m[6]*y+m[10]*z+m[14],m[3]*x+m[7]*y+m[11]*z+m[15]
end

function make_m_from_euler(x,y,z)
		local a,b = cos(x),-sin(x)
		local c,d = cos(y),-sin(y)
		local e,f = cos(z),-sin(z)
  
    -- yxz order
  local ce,cf,de,df=c*e,c*f,d*e,d*f
	 return {
	  ce+df*b,a*f,cf*b-de,0,
	  de*b-cf,a*e,df+ce*b,0,
	  a*d,-b,a*c,0,
	  0,0,0,1}
end

-- only invert 3x3 part
function m_inv(m)
	m[2],m[5]=m[5],m[2]
	m[3],m[9]=m[9],m[3]
	m[7],m[10]=m[10],m[7]
end
function m_set_pos(m,v)
	m[13],m[14],m[15]=v[1],v[2],v[3]
end
-- inline matrix invert
-- inc. position
function m_inv_x_v(m,v)
	local x,y,z=v[1]-m[13],v[2]-m[14],v[3]-m[15]
	v[1],v[2],v[3]=m[1]*x+m[2]*y+m[3]*z,m[5]*x+m[6]*y+m[7]*z,m[9]*x+m[10]*y+m[11]*z
end
-- returns up vector from matrix
function m_up(m)
	return {m[5],m[6],m[7]}
end

function collect_drawables(model,m,pos,zfar,out)
 -- vertex cache
 local p={}

 -- cam pos in object space
 local cam_pos=v_clone(cam.pos)
	m_inv_x_v(m,cam_pos)

 -- select lod
 local safe_pos=v_clone(cam_pos)
 -- todo: using nm?
 v_scale(safe_pos,1/64)
 local d=v_dot(safe_pos,safe_pos)
 
 -- lod selection
 local lodid=min(#model.lods,d>0.25 and 2 or 1)
 model=model.lods[lodid]

 -- reset collision groups
 local groups={}
 for _,f in pairs(model.f) do
  groups[f.gid]=0
 end

 -- model to
 local function v_cache(k)
  local a=p[k]
  if not a then
    a=v_clone(model.v[k])
    -- relative to world
    m_x_v(m,a)
    -- world to cam
    v_add(a,cam.pos,-1)
  		m_x_v(cam.m,a)

    -- pilot height (cam space)
  		v_add(a,pilot_pos,-1)
	   p[k]=a
  end
  return a
 end

	local clips
	local function set_clips(a)		
		local az=abs(a[3])
		if abs(a[1])>az or abs(a[2])>az then
			-- full clipping
			clips=clipplanes
	 end
	end

  -- faces
	for i=1,#model.f do
	  local f,n=model.f[i],model.n[i]
   -- front facing?
   if v_dot(n,cam_pos)>model.cp[i] then
	   -- reset clip planes
		  clips=clipplanes_simple
    -- face vertices (for clipping)
    local z,vertices=0,{}
    -- project vertices
    for k=1,#f.vi do
 			 local a=v_cache(f.vi[k])
     z+=a[3]
     -- select clip planes
     set_clips(a)
 		  vertices[#vertices+1]=a
    end
    if f.c!=15 then -- collision hull?
	    vertices=plane_clip(zfar,clips,vertices)
 	  	if(#vertices>2) add(out,{key=-64*#f.vi/z,v=vertices,c=f.c,kind=3})
  	end
   else
    groups[f.gid]+=1
   end
	 end

  -- collision check
 	for k,v in pairs(model.groups) do
			if v==groups[k] then
    make_msg("crash: collision with obstacle\nz: exit to menu", 300)
    sim.crashed=true
    --fix sound
    sfx(3)
   	break
   end
 	end

 -- edges
 -- viz distance
 local wfar=zfar and 120/zfar or 0
 for j=1,#model.e do
		local e=model.e[j]
  -- edges indices
  local c=e.c or model.c
  -- edge positions
  local a,b=v_cache(e[1]),v_cache(e[2])

  -- reset clip planes
  clips=clipplanes_simple

  if e.kind==1 or e.kind==4 then -- papi light?
   local x0,y0,w0=cam:project2d(a)
   if w0>wfar then
    -- papi light
    if e.kind==1 then
     local n=v_dot(a,a)-v_dot(a,b)
     c=n>0 and 7 or c
    end
    local r=mid(w0/4,0,3)
    add(out,{r=r,key=-w0,x=x0,y=y0,c=c})
    -- hightlight
    add(out,{r=r/2,key=-w0,x=x0,y=y0,c=c})
   end
  else

   -- select clip planes
   set_clips(a)
   set_clips(b)
			  
		 a[4],b[4]=0,e.n or 0
   local v=plane_clip(zfar,clips,{a,b,a})
   a,b=v[1],v[2]    
   -- hide light glare at low angle
   -- dot(cam up, up) --> 0,180 degrees
   -- *20 --> 0,9 degrees
   -- todo: explicit 'bloom' figure
   if a and b then
    local x0,y0,w0,u0=cam:project2d(a)
    local x1,y1,w1,u1=cam:project2d(b)
    if e.kind==0 then
     local bloom=lerp(24,12,mid(-20*cam.m[7],0,1))
     lightline(x0,y0,x1,y1,c,u0,w0,u1,w1,bloom,e.scale,out)
    else
     line(x0,y0,x1,y1,c)
				end
  	end
 	end
	end
end

-- sutherland-hodgman clipping
-- n.p is pre-multiplied in n[4]
function plane_clip(zfar,clips,v)
	for i=zfar and 1 or 2,#clips do
  if(#v<2) break
  v=plane_poly_clip(clips[i],v)
 end
	return v
end
function plane_poly_clip(n,v)
	local dist,allin={},0
	for i,a in pairs(v) do
		local d=n[4]-(a[1]*n[1]+a[2]*n[2]+a[3]*n[3])
		if(d>0) allin+=1
	 dist[i]=d
	end
 -- early exit
	if(allin==#v) return v
 if(allin==0) return {}

	local res={}
	local v0,d0,v1,d1,t,r=v[#v],dist[#v]
 -- use local closure
 local clip_line=function()
 	local r,t=make_v(v0,v1),d0/(d0-d1)
 	v_scale(r,t)
 	v_add(r,v0)
 	if(v0[4]) r[4]=lerp(v0[4],v1[4],t)
 	if(v0[5]) r[5]=lerp(v0[5],v1[5],t)
 	res[#res+1]=r
 end
	for i=1,#v do
		v1,d1=v[i],dist[i]
		if d1>0 then
			if(d0<=0) clip_line()
			res[#res+1]=v1
		elseif d0>0 then
   clip_line()
		end
		v0,d0=v1,d1
	end
	return res
end
function make_actor(model,p,angle)
  angle=angle and angle/360 or 0
	-- instance
	local a={
		pos=v_clone(p),
    model=all_models[model],
		-- north is up
		m=make_m_from_euler(0,angle-0.25,0)
  }

	-- init position
  m_set_pos(a.m,p)
	return a
end

function make_cam(x0,y0,focal)
	local c={
		pos={0,0,0},
		track=function(self,pos,m)
    self.pos=v_clone(pos)

		-- inverse view matrix
    self.m=m
    m_inv(self.m)
	 end,
		-- project cam-space points into 2d
    project2d=function(self,v)
  	  -- view to screen
  	  local w=focal/v[3]
  	  return x0+v[1]*w,y0-v[2]*w,w,v[4] and v[4]*w,v[5] and v[5]*w
		end,
		-- project cam-space points into 2d
    -- array version
    project2da=function(self,v)
  	  -- view to screen
  	  local w=focal/v[3]
  	  return {x0+v[1]*w,y0-v[2]*w,w,v[4] and v[4]*w,v[5] and v[5]*w}
		end
	}
	return c
end

function draw_clouds(weather)
 if(not weather.ceiling) return
 local cloudy=weather.ceiling/120-cam.pos[2]
 -- plane coords + u/v (32x32 texture)
 local cloudplane={
		{512,cloudy,512,0,0},
		{-512,cloudy,512,32,0},
		{-512,cloudy,-512,32,32},
		{512,cloudy,-512,0,32}}
 for _,v in pairs(cloudplane) do
  m_x_v(cam.m,v)
 end
	for i=1,#clipplanes do
	 cloudplane=plane_poly_clip(clipplanes[i],cloudplane)
	end
 tex_src=weather.tex
	color(cloudy<0 and 5 or 13)
 project_texpoly(cloudplane)
end

function draw_ground(weather)
	local horiz=weather.horiz
  -- update far clip plane=horizon limit
  clipplanes[1][4]=horiz
	-- draw horizon
	local zfar=horiz and -horiz or -128
	local farplane={
			{-zfar,zfar,zfar},
			{-zfar,-zfar,zfar},
			{zfar,-zfar,zfar},
			{zfar,zfar,zfar}}
	-- cam up in world space
	local n=m_up(cam.m)

 local sky_gradient,y0=weather.sky_gradient,cam.pos[2]

	-- ground dots
	local scale=3*max(ceil(y0/32),1)
	scale*=scale
	local x0,z0=cam.pos[1],cam.pos[3]
	local dx,dy=x0%scale,z0%scale

 color(1)
	for i=-4,4 do
		local ii=scale*i-dx+x0
		for j=-4,4 do
			local v={ii,0,scale*j-dy+z0}
			v_add(v,cam.pos,-1)
      m_x_v(cam.m,v)
      v_add(v,pilot_pos,-1)
      local x,y,w=cam:project2d(v)
			if w>0 then
				pset(x,y)
			end
  end
	end

 -- start alt.,color,pattern
	for i=1,#sky_gradient,3 do
		-- ground location in cam space
  -- offset by sky layer ceiling
		-- or infinite (h=0) for clear sky
		local p={0,-sky_gradient[i]/120,0}
		if(horiz) p[2]+=y0
		m_x_v(cam.m,p)
		n[4]=v_dot(p,n)
		farplane=plane_poly_clip(n,farplane)
		fillp(sky_gradient[i+2])
  -- display
		project_poly(farplane,sky_gradient[i+1])
	end
 fillp()

 -- stars (clear ceiling only)
 if not weather.ceiling then
  -- stars
  for _,v in pairs(stars) do
    v=v_clone(v)
    m_x_v(cam.m,v)
    local x,y,w=cam:project2d(v)
    if(w>0) pset(x,y,6)
  end
 end
end

function project_poly(p,c)
	if #p>2 then
		local x0,y0=cam:project2d(p[1])
    local x1,y1=cam:project2d(p[2])
		for i=3,#p do
			local x2,y2=cam:project2d(p[i])
			trifill(x0,y0,x1,y1,x2,y2,c)
		  x1,y1=x2,y2
		end
	end
end

function project_texpoly(p)
	if #p>2 then
		local p0,p1=cam:project2da(p[1]),cam:project2da(p[2])
		for i=3,#p do
			local p2=cam:project2da(p[i])
			tritex(p0,p1,p2)
			p1=p2
		end
	end
end

-- draw a light line
function lightline(x0,y0,x1,y1,c,u0,w0,u1,w1,bloom,scale,out)

 -- get color ramp from weather
 local ramp=wx[wnd].light_ramp or 64
 scale*=(wx[wnd].light_scale or 0.5)

 local w,h=abs(x1-x0),abs(y1-y0)

 local prevu,du,dw=-1
 -- inner loop function
 local light=function(x,y,u)
  if prevu and prevu!=u then
			local col=sget(ramp+3*mid(scale*w0-u%2,0,1),c)
   if col!=0 then
    pset(x,y,col)
   	-- avoid too many lights!
   	if bloom and w0>bloom then
		 		circfillt(x,y,min(3,24/w0),light_shades[c])
   	end
  	end
  end
  u0+=du
  w0+=dw
  prevu=u
 end

 if h>w then
  -- order points on y
  if(y0>y1) x0,y0,x1,y1,u0,u1,w0,w1=x1,y1,x0,y0,u1,u0,w1,w0
  w,h=x1-x0,y1-y0
	 du,dw=(u1-u0)/h,(w1-w0)/h

  -- y-major
  -- u0*=w0
	 if y0<0 then
		 local t=-y0/h
		 -- todo: unroll lerp
	  x0,y0,u0,w0=x0+w*t,0,lerp(u0,u1,t),lerp(w0,w1,t)
	  prevu=nil
  end

  for y=y0,min(y1,40) do
		 light(x0,y,flr(u0/w0))
   x0+=w/h
  end
 else
   -- x-major
	  if(x0>x1) x0,y0,x1,y1,u0,u1,w0,w1=x1,y1,x0,y0,u1,u0,w1,w0
	  w,h=x1-x0,y1-y0
	  du,dw=(u1-u0)/w,(w1-w0)/w

	  --u0*=w0
	  if x0<0 then
	    local t=-x0/w
	    -- u is not linear
	    -- u*w is
	    x0,y0,u0,w0=0,y0+h*t,lerp(u0,u1,t),lerp(w0,w1,t)
	    prevu=nil
	  end

   for x=x0,min(x1,127) do
				light(x,y0,flr(u0/w0))
		  y0+=h/w
	  end
	end
end

-->8
-- trifill
-- by @p01
function p01_trapeze_h(l,r,lt,rt,y0,y1)
  lt,rt=(lt-l)/(y1-y0),(rt-r)/(y1-y0)
  if(y0<0)l,r,y0=l-y0*lt,r-y0*rt,0
   for y0=y0,min(y1,128) do
   rectfill(l,y0,r,y0)
   l+=lt
   r+=rt
  end
end
function p01_trapeze_w(t,b,tt,bt,x0,x1)
 tt,bt=(tt-t)/(x1-x0),(bt-b)/(x1-x0)
 if(x0<0)t,b,x0=t-x0*tt,b-x0*bt,0
 for x0=x0,min(x1,128) do
  rectfill(x0,t,x0,b)
  t+=tt
  b+=bt
 end
end

function trifill(x0,y0,x1,y1,x2,y2,col)
 color(col)
 if(y1<y0)x0,x1,y0,y1=x1,x0,y1,y0
 if(y2<y0)x0,x2,y0,y2=x2,x0,y2,y0
 if(y2<y1)x1,x2,y1,y2=x2,x1,y2,y1
 if max(x2,max(x1,x0))-min(x2,min(x1,x0)) > y2-y0 then
  col=x0+(x2-x0)/(y2-y0)*(y1-y0)
  p01_trapeze_h(x0,x0,x1,col,y0,y1)
  p01_trapeze_h(x1,col,x2,x2,y1,y2)
 else
  if(x1<x0)x0,x1,y0,y1=x1,x0,y1,y0
  if(x2<x0)x0,x2,y0,y2=x2,x0,y2,y0
  if(x2<x1)x1,x2,y1,y2=x2,x1,y2,y1
  col=y0+(y2-y0)/(x2-x0)*(x1-x0)
  p01_trapeze_w(y0,y0,y1,col,x0,x1)
  p01_trapeze_w(y1,col,y2,y2,x1,x2)
 end
end

-->8
-- transparent drawing functions

-- init transparent colors
local shades=unpack_ramp(79)

function rectfillt(x0,y0,x1,y1)
	x0,x1=max(flr(x0)),min(flr(x1),127)

	for j=max(y0),min(y1,127) do
		linet(x0,j,x1,shades)
 end
end
function circfillt(x0,y0,r,ramp)
 if(r==0) return
 x0,y0=flr(x0),flr(y0)
 local x,y=flr(r),0
 local d=1-x

	-- default ramp or provided?
	ramp=ramp or shades

 while x>=y do
		linet(x0-x,y0+y,x0+x,ramp)
		if y!=0 then
			linet(x0-x,y0-y,x0+x,ramp)
		end
		y+=1

		if(d<0) then
			d+=shl(y,1)+1
		else
			if x>=y then
				linet(x0-y+1,y0+x,x0+y-1,ramp)
				linet(x0-y+1,y0-x,x0+y-1,ramp)
			end
			x-=1
			d+=shl(y-x+1,1)
		end
 end
end

function linet(x0,y0,x1,ramp)
 if(band(y0,0xff80)!=0) return
 if(x0>127 or x1<0) return
 x0,x1=mid(x0,0,127),mid(x1,0,127)

 if band(x0,0x1)==1 then
 	pset(x0,y0,ramp[pget(x0,y0)])
 	-- move to even boundary
 	x0+=1
 end
 if x1%2==0 then
 	pset(x1,y0,ramp[pget(x1,y0)])
 	-- move to odd boundary
 	x1-=1
 end

	local mem=0x6000+shl(y0,6)+shr(x0,1)
	for i=1,shr(x1-x0+1,1) do
		poke(mem,ramp[peek(mem)])
	 mem+=1
	end
end

-->8
-- unpack data & models
local mem=0x1000

-- unpack a list into an argument list
-- trick from: https://gist.github.com/josefnpat/bfe4aaa5bbb44f572cd0
function munpack(t, from, to)
 local from,to=from or 1,to or #t
 if(from<=to) return t[from], munpack(t, from+1, to)
end

-- w: number of bytes (1 or 2)
function unpack_int(w)
  w=w or 1
	local i=w==1 and peek(mem) or bor(shl(peek(mem),8),peek(mem+1))
	mem+=w
	return i
end
-- unpack a float from 1 byte
function unpack_float(scale)
	local f=shr(unpack_int()-128,5)
	return f*(scale or 1)
end
-- unpack a float from 2 bytes
function unpack_double(scale)
	local f=shr(unpack_int(2)-0x4000,4)
	return f*(scale or 1)
end
-- unpack an array of bytes
function unpack_array(fn)
	for i=1,unpack_int() do
		fn(i)
	end
end
-- valid chars for model names
local itoa='_0123456789abcdefghijklmnopqrstuvwxyz'
function unpack_string()
	local s=""
	unpack_array(function()
		local c=unpack_int()
		s=s..sub(itoa,c,c)
	end)
	return s
end

function unpack_models()
	-- for all models
	unpack_array(function()
  local model,name,scale={lods={}},unpack_string(),1/unpack_int()
  
		-- level of details
		unpack_array(function()
   local lod={v={},f={},n={},cp={},e={},groups={}}
   -- vertices
   unpack_array(function()
    add(lod.v,{unpack_double(scale),unpack_double(scale),unpack_double(scale)})
   end)

   -- faces
   unpack_array(function(i)
    local f={ni=i,vi={},c=unpack_int(),gid=unpack_int()}
    -- vertex indices
    unpack_array(function()
     add(f.vi,unpack_int())
    end)
    add(lod.f,f)
    -- collision group
    if(f.gid>0) lod.groups[f.gid]=1+(lod.groups[f.gid] or 0)
   end)

   -- normals
   unpack_array(function()
    add(lod.n,{unpack_float(),unpack_float(),unpack_float()})
   end)

   -- n.p cache
   for i=1,#lod.f do
    local f=lod.f[i]
    local cp=v_dot(lod.n[i],lod.v[f.vi[1]])
    add(lod.cp,cp)
   end

   -- edges
   unpack_array(function()
    local e={
       -- start
       unpack_int(),
       -- end
       unpack_int(),
   -- kind
   -- 0: lightline
   -- 1: papi light
       -- 2: regular
       kind=unpack_int(),
       -- color
     c=unpack_int()
     }
     -- number of light + light intensity
     if e.kind==0 then
       e.n,e.scale=unpack_int(),unpack_float()
     end

	   add(lod.e,e)
   end)

  add(model.lods,lod)
  end)
		-- index by name
		all_models[name]=model
	end)
end

-- unpack stars
unpack_array(function()
 add(stars,{unpack_float(),unpack_float(),unpack_float()})
end)

-- unpack models
unpack_models()

-->8
-- textured trifill
-- perspective correct
-- based off @p01 trifill
function trapezefill(l,dl,r,dr,start,finish)
	local l,dl={
		l[1],l[3],l[4],l[5],
		r[1],r[3],r[4],r[5]},{
		dl[1],dl[3],dl[4],dl[5],
		dr[1],dr[3],dr[4],dr[5]}
	local dt=1/(finish-start)
	for k,v in pairs(dl) do
		dl[k]=(v-l[k])*dt
	end

	-- cliping
	if start<0 then
		for k,v in pairs(dl) do
			l[k]-=start*v
		end
		start=0
	end

  -- cloud texture location + cam pos
  local mx,my,cx,cz=tex_src.x,tex_src.y,cam.pos[1],cam.pos[3]
	-- rasterization
	for j=start,min(finish,40) do
		local len=l[5]-l[1]
		if len>0 then
      local w0,u0,v0=l[2],l[3],l[4]
      -- render every 4 pixels
			local dw,du,dv=shl(l[6]-w0,2)/len,shl(l[7]-u0,2)/len,shl(l[8]-v0,2)/len
   for i=l[1],l[5],4 do
    local sx,sy=(u0/w0)%32,(v0/w0)%32
    -- shift u/v map from cam pos+texture repeat
    local c=sget(mx+band(sx*32-cx,31),my+band(sy*32-cz,31))
    if c!=0 then
     fillp(dither_pat[c+1])
	    rectfill(i-2,j,i+1,j)
		  end
			u0+=du
			v0+=dv
			w0+=dw
		 end
  end
		for k,v in pairs(dl) do
			l[k]+=v
		end
	end
end
function tritex(v0,v1,v2)
	local x0,x1,x2=v0[1],v1[1],v2[1]
	local y0,y1,y2=v0[2],v1[2],v2[2]
if(y1<y0)v0,v1,x0,x1,y0,y1=v1,v0,x1,x0,y1,y0
if(y2<y0)v0,v2,x0,x2,y0,y2=v2,v0,x2,x0,y2,y0
if(y2<y1)v1,v2,x1,x2,y1,y2=v2,v1,x2,x1,y2,y1

	-- mid point
	local v02,mt={},1/(y2-y0)*(y1-y0)
	for k,v in pairs(v0) do
		v02[k]=v+(v2[k]-v)*mt
	end
	if(x1>v02[1])v1,v02=v02,v1

	-- upper trapeze
	-- x u v
	trapezefill(v0,v1,v0,v02,y0,y1)
	-- lower trapeze
  trapezefill(v1,v2,v02,v2,y1,y2)
  -- reset fillp
  fillp()
end

__gfx__
00000000fff7777f49777777777777e25fffffff666666666666666666666666000000000000000000000000ffffffffffffffff666666667777777770ffffff
00000000ff7fffffffffffffffffffff55ffffff666666666666666666666666001100010100001d00000000fffffffffff66666777777771c66666660ffffff
00000000f7ffffffff3b77777777d5ff555fffff000000000000000000000000000000002280002e00000000ffffffff6667777755555555cc66666660ffffff
000000007fffffffffffffffffffffff55ffffff0000077707770777007700770000000053b0003b00000000ffffff667775555511111111c777777760ffffff
00000000ffffffffffff1c7777c1ffff5fffffff000007000070070007000700000000002490004500000000ffff667755511111000000001777777760ffffff
00000000ffffffffffffffffffffffffffffffff000007700070077007000777000000005560005600000000ffff77551110000000000000c555555560ffffff
00000000ffffffffffffffffffffffffffffffff000007000070070007070007015600565670006d00000000ffff55110000000000000000c555555560ffffff
00000000ffffffffffffffffffffffffffffffff000007770070077707770770567706775770007600000000ffff11000000000066666666cc05550660ffffff
00000000ffffffffffffffff77777fffffbfffffc000000cff222fffffffffff128802882880008e00000000ffff000000066666666666661c10001660ffffff
00000000fffffffffffffffff777fffffbffffffccccccccf2e7e2ffff0fffff4449054929a0009a00000000ffff000066666666666666667710001660ffffff
00000000ff555fffffffffffff7fffffbbbbbbbb000000002ee7ee2ff00fffff49af009a4aa000a700000000ffff006666666000000000007751115660ffffff
00000000ff555ffffffffff0fffffffffbffffffcc0000002ee7ee2f000fffff033b003b3bb000b600000000ffff666666666000000000006765556660ffffff
00000000ff555fffffffff00ffffffffffbfffff0c00cc002ee7ee2ff00fffff011c000c1cc000cd00000000ffff666666666000000000007766666660ffffff
00000000fffffffffffff000ffffffffffffffff0c00c0c0f2e7e2ffff0fffff000000005d6000d600000000ffff666666666000000000007766666660ffffff
00000000fffffffffff00000ffffffffffffffff0c00c0c0ff222fffffffffff000000002ed000ef00000000ffff666666666000000000006766666660ffffff
00000000ffffffff00000000ffffffffffffffffccc0c0c0ffffffffffffffff000000005f7000f600000000ffff66666666600000000000ddddddddd0ffffff
00000000ff7ffffffff0000000000000777fffff777ffffffbfffffffffffffffff00000fff00000000fffffffff6666666660000000000077777777cccccccc
0000000077777ffffff0000000000c007fffffff77ffffffbbbfffffffcccfffff00ccc0ff000cc0000fffffffff6666666660ffffffffff1c666666cccccccc
00000000ff7fffffff000000000000c0ff7fffff7ffffffffbfffffffcfffcfff000c0c0f000c000000fffffffff6666666660ffffffffffcc666666cccccccc
00000000ff7fffffff000000cccccccc777fffff777ffffffffffffffcfcfcff0000cc000000c000000fffffffff6666666660ffffffffffcc666666cccccccc
00000000f777ffffff000000000000c0fffffffffffffffffffffffffcfffcfff000c0c0f000c0c0cccfffffffff6666666660ffffffffff1c666666cccccccc
00000000fffffffff000000000000c00ffffffffffffffffffffffffffcccfffff00c0c0ff00ccc0cccfffffffff6666666660ffffffffffcc666666cccccccc
00000000fffffffff000000000000000fffffffffffffffffffffffffffffffffff00000fff00000c0cfffffffff6666666660ffffffffffcc655566cccccccc
00000000ffffffff00000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffc0cfffffffff6666666660ffffffffffcc511156cccccccc
aaaaaaaa99999999444444442222222277ffffff7f7fffffff222fffff222ffffff00000fff0000033333333ff000000666660ff0000ffff1c10001600000000
aaaaaaaa9999999944444444233233227f7fffff7f7ffffff2eee2fff2eee2ffff00c0c0ff00c0c033333333ff000000666660ff0000ffff7710001600000000
aaaaaaaa9999999944444444232332327f7fffff777fffff2eeeee2f2eee7e2ff000c0c0f000c0c033333333ff005555666660ff5550ffff770ddd0600000000
aaaaaaaa9999999944444444223323327f7fffff777fffff2777772f2ee7ee2f00000c000000ccc033333333ff005666666660ff6650ffff67ddddd600000000
aaaaaaaa999999994444444423323322ffffffffffffffff2eeeee2f2e7eee2ff000c0c0f00000c033333333ff005555666660ff5550ffff7ddddddd00000000
aaaaaaaa999999994444444423233232fffffffffffffffff2eee2fff2eee2ffff00c0c0ff00ccc033333333ff005555666660ff5550ffff7555555500000000
aaaaaaaa999999994444444422332332ffffffffffffffffff222fffff222ffffff00000fff0000033333333ff001111666660ff1110ffff6555555500000000
aaaaaaaa999999994444444422222222ffffffffffffffffffffffffffffffffffffffffffffffff33333333ff000000666660ff0000ffffd111111100000000
1468988410000000000000000000000000066666666666666666666666666666ffeaaceb8877642467678bfb7433338cffff6666666660ffffffffffffffffff
67affffa50000000000000000000013366666666666666666666666666666666cdcffffd82333101333469b963000159ffff6666666660fff000000ff000000f
9bfffffc920000000000000000001467666660000000000000000000000000009bffffffc51001333234777654332467ffff6666666660fff070000ff000070f
ccfffffeb4000000000000000000369b66666007700777070700700000000007ccfffffffa411467787777445676779bffff0000000000fff007070ff070700f
cbdffeccb510000000000000000037bf66666007070707070707700000000007cbdffffffe73369bcccb96349cea9abfffff0000000000fff000770ff077000f
aadfeb8562000000000000000000369b66666007070777070700700000000007aadffffffd7337bfeeefb747dfffb99bffff0000000000fff007770ff077700f
aabfc82000000000000000000000146866666007070707070700700000000007aacfffedc963369bcccba99cffffa768ffff0000000000fff000000ff000000f
cdffc50000000000000000000000014966666007070707007007770000000007ffffffdca64247987878aabefffd724affff0000000000ffffffffffffffffff
efffc60000200000000000000000014966666666666666666666666666666666ffffffca6344689742369aefffc9415dffff0000000000ffffffffffffffffff
ffea852002520000000000000000036c66666666666666666666666666666666ffffffb632889b9630037bffed97239fffff0000000000fff000000ff000000f
cb93034558875444331000000000049c70000000000000000000000000000000fffe9aa968befffb631369bbdca745cfffff0000000000fff007770ff077700f
86300069ccdb9899964100000000168970000ee0000000007007770077000000ffc763adffffffffc6424679aab979bfffff0000000000fff000770ff077000f
43000016aabdcccec96300000000347670000e0e0e0000000700700700000000aa64115dffffffffd96313368bfba78affff0000000000fff007070ff070700f
01000000368cfffffb730001333134547000eeeeeee0000007007007770000003431036cfffffffffb7300049cea9755ffff0000000000fff070000ff000070f
134641000369bcccb96300146764433270000e0e0e00000007007000070000001346448ffffffffeec940015adda8432ffff0000000000fff000000ff000000f
576763200146778776410169cc96433470000eee000000007707770770000000676767cffffffffedda51169dfca9998ffff0000000000ffffffffffffffffff
88986410001333233310149efeb73266ff0000000000ffff6666666666666666d99868bfffffffcccea6449efeccdfffffffffffffffffff000666666666ffff
aa96310000000000000036cffc962036ff0000070000ffff6666666666666666fe96348effffc9adefc766cffccfffff66666fffffffffffff0666666666ffff
ba73000000000000000037cffc830005ff0000575000ffff0000000000000000ff830369baa977bdffd767cffcbdffff77777666ffffffffff0666666666ffff
56630000000000000000369cdc910000ff0005575500ffff7770077000007770ff9301467654368dffc879cddccaffff5555577766ffffffff0666666666ffff
034100000000000000001468abb60000ff0005555500ffff7070700000007070fb71001346458cfffeb87bccbbcbdfff111115557766ffffff0666666666ffff
001000000000000000000136aee96000ff0005555500ffff7700700000007700a6400001469ffffffa999cccdeeadcff000001115577ffffff0666666666ffff
000000000000000000000003affeb300ff0001555100ffff70707070000070709720000369fffffff978bfbadffec77a000000001155ffffff0666666666ffff
0000000000000000000000039fffe700ff0000111000ffff7070777000007770a74100037bfffffff6469b99cfffe979000000000011ffffff0666666666ffff
1000000000000001333100017cffea63666670ff666660ffd56660ff70000000c963000369fffffff64567658cffedcc666660000000ffffff066666ffffffff
41000000000000279a741000279bba86666660ff666660ffd56660fffffffffffc730001469ffffffb768995379bbdff666666660000ffffff066666f000000f
630000000133447cced7300001369ab9666660ff666660ffd56660fffffffffffc6300001468cdffdeecddda5369ceff000666666600ffffff066666f000000f
73000000146899989bea300000037bfb666660ff666660ffd56660ffffffffffff610133469bca99ceffffffa76adfff000666666666ffffff066666f000000f
63000000369ec96469c93000000369b9666660ff666660ffd56660ffffffffffff921467aefffd88cfffffffd99effff000666666666ffffff066666f000000f
4100000037bfc8404897100000014676666660ff666660ffd56660ffffffffffffc6369bfffffea6dfffffffdabfffff000666666666ffffff066666f000000f
10000000236bb9646642000000001333666660ff666660ffd56660ffffffffffffe637bfffffffcbffffffffc89bafff000666666666ffffff066666f000000f
01333112010255321000000000000000666660ff6666d0ffd56660fffffffffffff967adcdcdeb98ab9adffd87676adf000666666666ffffff066666ffffffff
030739496988b6f8e876d7f9780719a60a38189899e677d99866c8f886594817a9b84609c7180af74648f878397626a848288959486979180a58b74976373969
3678c8c8495987f948080a38f7f987c70a3827083677c927c8b957b7a92988e997269868b7381656780748d9479939081938b966c82757e9b787f9f757e9b737
f87658180aa639374749a6380a38a7d9c85030c0b1f10320f6f38a04000407f38c04000407f38a04002405f38c04002405f38d04000407f38f04000407f38d04
002405f38f04002405048004000407048204000407048004002405048204002405048304000407048504000407048304002405048504002405f3010400040004
0f04000400f3010400d90c040f0400d90cf38404000407f38604000407f38404002405f38604002405f38704000407f38904000407f38704002405f389040024
05048604000407048804000407048604002405048904000407048b04000407048904002405048b04002405f38104000407f38304000407f38104002405f38304
002405048c04000407048e04000407048c04002405048e0400240504000400040004000400b80004000400d90c04000400b80004000400320ef30a0400d20404
060400d204f3070400320e04090400320ef3010400630a040f0400630a04000400630a04000400320e040f0400730e54450400730e540f040083e774030400c4
1874dc0400d402540f0400361e64070400630a040f0400e58e040f040016e2540f040066e225070400d40204000400732e04000400930c04c904007304548f04
00730464490400730e64490400461e04870400f58a548e040056d004870400d55135180400850c451c040075083518040075083518140f7508451c140f750835
18140f850c451c140f850c048804002405451c0400850c2507040095e074dc040095e07403040095ea64dc040066e27403040056cc74030400730674dc0400d4
9b74dc04008567143e040063a2143e0400834335182403850c451c2403850c451c2403750835182403750835182404850c451c24047508451c2404850c351824
047508a3060400f40aa3063400f44bb30a0400f40ab30a24fff41cc30e0400f40ac30e24fff4fce3020400f40ae30224eff4cd21700040102040307000405060
807070004090a0c0b0700040d0e001f07000405161817170004091a1c1b170004002123222700040425272627000408292b2a200104025d4f4050010403555d4
25d010403525061600004016063626d0104005152636700040d1e145f100104005f4e415001040551626e4d010402505360621080a08080a08080a08080a0808
0a08080a08080a08080a08080a0806080808080a08080a080a08080806080a080808060a0808060808423111007023a91441007002a9c2d20060050ae2f20080
620a13230070200a33430070200a112100b0e10a31410080e10a73830070e10ab5c300c01138e3b300c03238241400c0603804e300c06038d33400c09038c4a4
00b08038544400b06038647400b01138948400b00938a4b400b0913893a300c040382114007021a9a58500c0a038657500c0903863f300c04038346500c0a038
952400c02038c5d500a09338e5f500a0b0380646408016664080367640802656408086961080a6b61080c6d61080e6f6108070f30104000400040f04000400f3
010400d90c040f0400d90c04000400320e04000400630a04000400320e0000503010007023a9102000b0e10a30400080e10a60700070e10a2040007023a930e0
f142102054e31d04001403e3e9040004bfe314040004dbd3dd04000450d31f0400f3d2e3c80400e36ff3b10400e3dcf3880400e3bf04a20400f380040a0400f3
d104af0400f3f304cf0400f30b1432040004b3049804001424f3ed040014e5d3da0400e3a3d33804001462f31a0400244424e20400240424960400e3eff30a04
00d303f3bd0400f37ff31e0415f3aff36e04000471f39e04150401f3bf0400f3cef38f0415f32f0460040004b0040004150480f3090400f37ff3090463f37ff3
5a04000401f35a04630401f39a0400f31ef39a0463f31ef3fb0400f3aff3fb0463f3aff3ab040004a5f3ab043204a5f31a04000407f31a04320407f30d040004
37f30d04320437f37b04000498f37b04320498e367040004db14130400f30bd3e8040014e324370400f34104340400f310f36f04001475f37b04002494f38b04
00d392e3ca0400e36f048a04001424d3ab0400e3a2245304002423f31e0435f3aff39e04350401f38f0435f32f040004350480f3090483f37ff35a04830401f3
9a0483f31ef3fb0483f3aff3ab045204a5f31a04520407f30d04520437f37b04520498f0001040617191810010408191d1c1001040c1d1b1a1001040a1b17161
002040e1f1120200204002125242002040425232220020402232f1e1003040627292820030408292d2c2003040c2d2b2a2003040a2b2726200004072b2d29200
0040f132521200004071b1d191f02628b8b828e9e928575728268608595908898908b6b60886b608868608595908898908b6080a08080a08080a08d220100090
700a30200090b00a40300090510a50400090610a60500090010a70600090f00a80700090c00a90800090010aa0900090c00ab0a00090a00ac0b00090b00ad0c0
0090e00ad0e00090f10af0e00090110a10f00090b10a60e00090e40a30c00090b40a90f00090c30a60010090d10a30110090610af0210090810ae0310090130a
c0410090920a90510090130ae2f20090b40ae2030090b10af2130090420a23330090c30a33430090910a23530090130a63730090e40a63830090020a73930090
e20ad1d34080c3b14080d254408044b2408091b340809234408071a340807224408032044080e3f140805214408012f3408011e31d04001403e3740400047cd3
dd04000450d31f0400f3d2f3b10400e3dcf3880400e3bf04af0400f3f31432040004b30439040014c3f38e040014c5d37d0400e330d37804001413f3aa040024
2524920400240324870400f36204430400f3c0f3ea0400d32300001110200090300a30200090400a40300090400a60500090200a80900090600aa0900090300a
10a00090600a40500090600a20f00090710aa0010090c00a90b00090610a20c00090400aa0d00090500a90e00090900a70800090500a60700090800a01110090
a00a4021d191f010105156080400a52815410400040035f10400d4d5f418040064f8757d0400d4983660040064d756520400449af558040054ba2656040024c6
e59a04003401e4670400d427c4bf0400c4c3a461040084d394a5040044aaf5d40400252c8564040095de65dd040095b3452b0400257935600400150865250400
557c169204007491000021503020104030201020402010f05020107060201080a0201051802010a090201090702010c0b00090130ad0c00090e70ae0d00090d5
0a10f0201011010090820a41110090a50a31210090330a21410090c50a60512010708191f110d041211010a034da0400f32a148b0400c306a3a70400d34dd30b
040034bb2405040024d6f32f340e042c043e343a043a146434a8f3aff30834cff3bb04db34caf314600010401080a02000104020a09030001040309060400010
4040607050001040507080100010506090a0807060791927b73966b659b88809b99909c888f9080040e13141b1102042f38c0400f34ff38c040004c004700401
040104700401f30ff30c0401f30ff30c0401040104b1040004c004b10400f34f04020401040104020401f30ff38b04000400049004d1f33ff38a040104000490
04d104d004e104d104d004e104d1f33f046104d1f3df04610492f3df046104d1043004610492043004d104d1f3df04b10492f3df04d104d1043004b104920430
046004a1f3ce04600412f3ce046004a1044104600412044104d004a1f3ce04d00412f3ce04d004a1044104d004120441f38a0421040004600422f3ce04600422
044104b3040004009100105050a09060d00020403040c0e00010401050d0b0001040702060900010407090a080f020403090a040001040a0501080002040e0c0
01f00010406020b0d00020409030e0f0002040a090f00100204040a001c000404011214131004040314181710040407181615100404051612111f04040317151
1100404081412161d0304091a1c1b1d03040b1c102f1003040f102e1d1d03040d1e1a191003040b1f1d19100304002c1a1e110103070804291080a0806480807
17960887f9f97708080608088716080a080717790888f90a480808881606080808080a0a4808080806080608080a0806080808080a0a0808080806080608080a
08080a0830c13240b022a14080d012407031f38c0400f34ff38c040004c004700401040104700401f30ff30c0401f30ff30c0401040104b1040004c004b10400
f34f04020401040104020401f30ff38b04000400049004d1f33ff38a04010400049004d104d004e104d104d004e104d1f33f049004f104d0049004f1f33ff38a
04210400c000005050a09060d00000403040c0e00000401050d0b0000040702060900000407090a080f000403090a040000040a0501080000040e0c001f00000
406020b0d00000409030e0f0000040a090f00100004040a001c0c0080a080648080717960887f9f97708080608088716080a080717790888f90a480808881630
e01140b021c04080d031407000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__label__
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111116111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111127777777771127777777771127777777111127777277771111111111111111127777771127777777771127777777771111111111111111
11111111111111111127777777771127777777771127777777111127777277771111111111111111127777771127777777771127777777771111111111111111
11111111111111111127777777771127777777771127777777111127777277771111111111111111127777771127777777771127777777771111111111111111
11111111111111111111127777111111127777111127777277771127777777771111111111111127777111111111127777111127777777771111111111111111
11111111111111111111127777111111127777111127777277771127777777771111111111111127777111111111127777111127777777771111111111111111
22222222222222222222227777222222227777222227777277772227777777772222222222222227777277772222227777222227777777772222222222222222
22222222222222222222227777222222227777222227777277772222222277772222222222222222222277772222227777222227777277772222222222222222
22222222222222222222227777222222227777222227777277772222222277772222222222222222222277772222227777222227777277772222222222222222
22222222222222222222227777222227777777772227777277772227777777772222222222222227777777222227777777772227777277772222222222222222
eeeeeeeeeeeeeeeeeeeee27777eeee2777777777ee2777727777ee2777777777eeeeeeeeeeeeee27777777eeee2777777777ee2777727777eeeeeeeeeeeeeeee
eeeeeeeeeeeeeeeeeeeee27777eeee2777777777ee2777727777ee2777777777eeeeeeeeeeeeee27777777eeee2777777777ee2777727777eeeeeeeeeeeeeeee
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000010000000001000000010000000000100000000000000000000000000000000000000000000000000000000
00000001000000000000000000001000000100000000000000100000000000100000000000000000000000100000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000100000000000000000000000000000001000000000000000000000000000100000000000000000000
00000000000010000000000000000000000000000000000000000000000000000000000000000000000007885000000000000000000000000000000000000000
00000000000000000000010000000000000000000000000000000000000000000100000000000000005118700000000000000000100000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000076616500000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000716c7cbc000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000076677bbb1c3000000000000000010000000000000000000000000000
0000000000000000000000000000000000000100000000000000000000000000000066667600cc3ac01c10000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000767677000cba99000000c1c01c0000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000705767000011bba01c1000000000100000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000677700000cbbb00000000c1c01cc1000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000700000ccbbc000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000b000000000ccbbb000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000070caac00000ccbbc00000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000077700a0cbccbcbbb00000000000000000000000000000000000000000000000000000000000000000
0d10000000000000000000000000000000000000000077700000000000ccc0000000000000000000000000000000000000000000000000000000000000000000
6666d10d500000000000000000000000000000007777000000000000000000000000000000000000010000000000000000000000000000000000000000000000
67776667666500000000000000000000000007770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55567767777666100000000000000000000770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
11555dd55d7776666000000000000077770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0111151115556777666d000000077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000110011115556777666d070700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000111555d67776665000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000001111555d67776665000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
65001100000000001111555d77766661000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6666666d1000000000011115556777666d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6666666666d0000000000011115556777666d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
60566666666665000000000001115555677766650000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
50000d6666666666500000000000111555d677766650000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0d770001d6666666666100000000001111555d777666610000000000000000000000000000000000000000000000000000000000000000000000000000000000
075d00d50016666666666d100000000001111555d777666d00000000000000000000000000000000000000000000000000000000000000000000000000000000
070d60777600056666666666d0000000000011115556777666d00000000000000000000000000000000000000000000000000000000000000000000000000000
d6075170660700005666666666650000000000011155556777666500000000000000000000000000000000000000000000000000000000000000000000000000
75170676715706d0000d6666666666500000000000111555d6777666500000000000000000000000000000000000000000000000000000000000000000000000
60660756706d0705770001d6666666666500000000001111555d7776666100000000000000000000000000000000000000000000000000000000000000000000
00515706d0705700d70000001d666666666d100000000001111555d7776666000000000000000000000000000000000000000000000000000000000000000000
c300050705777d00750003bb00056666666666d0000000000011115556777666d000000000000000000000000000000000000000000000000000000000000000
cccc1000005760007000003bb0300056666666666d00000000000111155567776665000000000000000000000000000000000000000000000000000000000000
ccccccc1001500dd600000b000bbb3000d6666666666500000000000111555d67776665000000000000000000000000000000000000000000000000000000000
cccccccccc100067750000b0000b330b3000d6666666666500000000001111555d77776661000000000000000000000000000000000000000000000000000000
ccccccccccccc10055003b30001b003bb000001d666666666d100000000001111555d77766661000000000000000000000000000000000000000000000000000
ccccccccccccccc30000bbb000b300b30b00000d656666666666d1000000000011115556777666d0000000000000000000000000000000000000000000000000
cccccccccccccccccc10003000b000b03b000007500056666666666d0000000000011115556777666d0000000000000000000000000000000000000000000000
ccccccccccccccccccccc10000b003b0b30000170000000566666666665000000000001115555677766650000000000000000000000000000000000000000000
cccccccccccccccccccccccc10000b30b000006600000e2000d6666666666500000000001111555d677766650000000000000000000000000000000000000000
ccccccccccccccccccccccccccc10003b000007100002ee000001d6666666666100000000001111555d777666610000000000000000000000000000000000000
ccccccccccccccccccccccccccccc30000000570000ee20e000000056666666666d100000000001111555d777666d00000000000000000000000000000000000
cccccccccccccccccccccccccccccccc300006d00002eeee0e2000200056666666666d0000000000011115556777666d00000000000000000000000000000000
ccccccccdcccccccccccccccccccccccccc107000002e0eeee2000dee40005666666666650000000000011155556777666500000000000000000000000000000
ccccccccddddcccccccccccccccccccccccccc10000ee2e02ee0000e240e2000d6666666666500000000000111555d6777666500000000000000000000000000
cccccccddddddddcccccccccccccccccccccccccc1002ee02200001e001ee000001d6666666666500000000001111555d7776666100000000000000000000000
cccccccdddddddddddcccccccccccccccccccccccccc0000000000d400e40e02e02001d666666666d100000000001111555d7776666000000000000000000000
cccccccd66dddddddddddccccccccccccccccccccccccc30000000e000e02e0e20e0000056666666666d0000000000011115556777666d000000000000000000
ccccccddd6dddddddddddddcccccccccccccccccccccccccc10001e002e0e20e22e0000000056666666666500000000000111155567776665000000000000000
ccccccdd66dd666ddddddddccccccccccccccccccccccccccccc10000e20e002ee200000000000d6666666666500000000000111555d67776665000000000000
cccccddd6ddddd66d6dddddcccccccccccccccccccccccccccccccc10002e0200e000000000055001d6666666666500000000001111555d77776661000000000
77cccddd6ddd6d66d6666dcccccccccccccccccccccccccccccccccccc1000eeee000000000067700001d666666666d100000000001111555d77766661000000
4f776d666dd6666dd6d66dcccccccccccccccccccccccccccccccccccccc3000220000000000705507610056666666666d1000000000011115556777666d0000
4444666666d6dddd66d6ddccccccccccccccccccccccccccccccccccccccccc1000000000005707d01777000056666666666d0000000000011115556777666d0
444455d6666666dd6dd6dccccccccccccccccccccccccccccccccccccccccccccc1000000007d07000700007d000566666666665000000000001115555677766
444455555dddd6dd6d6ddcccccccccccccccccccccccccccccccccccccccccccccccc1000007dd700d700d657500000d6666666666500000000001111555d677
4445555555666ddd666dcccccccccccccccccccccccccccccccccccccccccccccccccccc10057750075007610001e02001d6666666666100000000001111555d
44455555555d666dddddcccccccccccccccccccccccccccccccccccccccccccccccccccccc30000d77500567600e40e0000056666666666d1000000000011115
44455555555555d666ddccccccccccccccccccccccccccccccccccccccccccccccccccccccccc3000d70d107100e22e0000000056666666666d0000000000011
44555555555555555d676ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc100067650002ee2000000e10005666666666650000000000
44555555555555555554f776ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc1000000000e0000000e0000000d666666666650000000
44555555555555555554444f7ccccccccccccccccccccccccccccc776ccccccccccccccccccccccccccccc1000002e0000004e0000000001d666666666650000
45555555555555555544444446ccccccccccccccccccccccccccccc6777cccccccccccccccccccccccccccccc00022002000eee2000000000016666666666d10
45555555555555555544444447776ccccccccccccccccccccccccccccc6776ccccccccccccccccccccccccccccc30000e001e0e4000000000000056666666666
115555555550155555444444444e7776ccccccccccccccccccccccccccccc6776ccccccccccccccccccccccccccccc10000de4e1000000000007d00056666666
000015555550100154444444444444f777cccccccccccccccccccccccccccccc6cccccccccccccccccccccccccccccccc1001de0000000000d756500000d6666
07750001550577d004444444444444444f776ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc10000000000007500051770001d6
007500500006d57014444444444444444444f776ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc100000000070000750d001200
0170017700076100444444444444444444444447ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc3000000d7071177d0002ee0
06600057000567d044444444444444444444444e76cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc1000d777000571000e20
1710007d00610702444444444444444444444444e7776cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc1001d07d570000e00
77d0007000677704444444444444444444444444444e777ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc10056100002e00
0560767001005504444444444444444444444444444444f777ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc100000ee200
5000577707501024444444444444444444444444444444444f776cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc30002ee20
55510001070d6044444444444444444444444444444444444444f77cccccccccccccccccccccccccccccccccccccccdddccccccccccccccccccccccccc300002
55555510d7575044444444444444444444444444444444444444446cccccccccccccccccccccccccccccccccccccccdddddcccccccccccccccccccccccccc100
555555500d7704444444449a444444444444444444444444444444f776ccccccccccccccccccccccccccccccccccccddddddddcccccccccccccccccccccccccc
555555000066044444444449aaa44444444444444444444444444444e7776ccccccccccccccccccccccccccccccccddddddddddddccccccccccccccccccccccc
55555500007104444444444444aa4444444444444444444444444444444e777ccccccccccccccccccccccccccccccdddddddddddddddcccccccccccccccccccc
5555551000d044444444444444444444444444444444444444444444444444f777cccccccccccccccccccccccccccddddddddddddddddddccccccccccccccccc
55555555510044444444444444444444444444444444444444444444444444444f776cccccccccccccccccccccccdd6ddddddddddddddddddccccccccccccccc
55555555555544444444444444444444444444444444444444444444444444444444f6ccccccccccccccccccccccdd66ddddddddddddddddddcccccccccccccc
55555555555444444444444444444444444444444444f44444444444444444444444476cccccccccccccccddbcccdd66dd66ddddddddddddddcccccccccccccc
55555555555444444444444444444444444444444444f77f4444444444444444444444f776ccccccccccccbbbdcddd6ddd6d66ddddddddddddcccccccccccccc
66555555554444444444444444444aa94aa944a4444444e7f44444444444444444444444e7776cccccccccdbbbcddd6ddd6d6dd666dddddddccccccccccccccc
5655555555444444444444444444444a949aaa9aaa4aa944a94444444444444444444444444e777ccccccddbdccd666dd6dd6d66d6dd6ddddccccccccccccccc
d655d66d554444444444444444444444444444444aa44aaa9aaae4444444444444444444444444f777cccd76dcddd66dd6d66d6dd6d6666ddccccccccccccccc
6d556dd65444444444444444444444444444444444444444444a77444444444444444444444444444f776ddddcddddddd666dd6d66d6dd6dcccccccccccccccc
655565d65444444444444444444444444444444444444444444aaa444444444444444444444444444444ddddcdddddddddd6d66d6dd6d66dcccccccccccccccc
6d5d656d5444444444444444444444444444444444444444444449aa4444444444444444444444444444666dcddddddddddddd666d66d6ddcccccccccccccccc
d656d56544444444444444444444444444444444444444444444444444444444444444444444444444445d6776dddddddddddddddd6666dccccccccccccccccc
555d6665444444444444444444444444444444444444444444444444aaa4444444444444444444444445d554d666ddddddddddddddd666dccccccccccccccccc
5555555544444444444444444444444444444444444444444444444444aa4444444444444444444444456d54555d666dddddddddddddddcccccccccccccccccc
5555555444444444444444444444444444444444444444444444444444449444444444444444444444555544555555d666ddddddddddddcccccccccccccccccc
55555554444444444444444444444444444444447e444444444444444444aaa944444444aa944444445555466d555555566dddddddddddcccccccccccccccccc
4445555444444444444444444444444444444444f7774444444444444444444a9444444444aaa94444555540566555555101dddddddddccccccccccccccccccc
4444444444444444444444444444444444444444444fe4444444444444444444a94444444444444445555420000155555051001ddddddccccccccccccccccccc
444444444444444444444444444444444444444444447f4444444444444444449aaa444444444444477d54000000001550677d0001dddccccccccccccccccccc
444444444444444444444444444444444444444444444f77f44444444444444444444444444444444567f40000005d0000006607d000dccccccccccccccccccc
444444444444444444444444444444444444444444444444f74444444444444444444444444444445555420000007777000675177760777ccccccccccccccccc
4444444444444444444444444444444444444444444444444444444444444444444444444444444455554000000070d700067066071044f776cccccccccccccc
4444444444444444444444444444444444444444444444444444444444444444444444444444444455554000000d777516566071570444444fcccccccccccccc
144444444444444444444444444444444444444444444444444444444444444444444444444444455554200000000d700d7715706d0444444e76cccccccccccc
000244444444444444444444444444444400044444444444444444444444444444444444444444457d545100000006605001067d70144444444f776ccccccccc
00024444444000444444444444444444440610004444444444444444444444444444444444444445d544566d10000751776100567044444444444e7776ccccc0

__gff__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000020000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0b0c0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d6c6d3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a2f2f2f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1b4445461d1d54551d4756571d67661d1d1d54551d1d1d071d1d1d05061d1d1d7c7d3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a2f2f2f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2b2c2d2d2d2d772d2d2d2d2d2d2d2d2d2d2d772d2d2d2d2d2d2d2d2d2d2d2d2d6e6f3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a2f2f2f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2b3c0000000000000000000000000000003f3f3f3f3f3f3f3f3f3f3f3f3f00007e6f3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a2f2f2f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2b3c0000000000000000000000000000003f3f3f3f3f3f3f3f3f3f3f3f3f00007e6f3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a2f2f2f2f2f2f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2b740000000000000000000000000000003f3f3f3f3f3f3f3f3f3f3f3f3f00007e6f3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a2f2f2f2f2f2f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2b7500000000000000000000000000003f3f3f3f3f3f3f3f3f3f3f3f3f3f00007e6f3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a2f2f2f2f2f2f2f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2b3c00000000000000000000000000003f3f3f3f3f3f3f3f3f3f3f3f3f3f000064653a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a2f2f2f2f2f2f2f2f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2b760000000000000000000000000000003f3f3f3f3f3f3f3f3f3f3f3f3f3f0064653a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a2f2f2f2f2f2f2f2f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2b760000000000000000000000000000003f3f3f3f3f3f3f3f3f3f3f3f3f3f003b3d3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a2f2f2f2f2f2f2f2f2f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2b760000000000000000000000000000003f3f3f3f3f3f3f3f3f3f3f3f3f3f003b3d3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a2f2f2f2f2f2f2f2f2f2f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4c4d0000000000000000000000000000003f3f3f3f3f3f3f3f3f3f3f3f3f3f007e6f3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a2f2f2f2f2f2f2f2f2f2f2f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5c5d0000000000000000000000000000003f3f3f3f3f3f3f3f3f3f3f3f3f3f007e6f3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a2f2f2f2f2f2f2f2f2f2f2f2f2f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f0000003a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a2f2f2f2f2f2f2f2f2f2f2f2f2f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000003f000000003a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a333a3a2f3a3a3a3a3a3a3a2f2f2f2f2f2f2f2f2f2f2f2f2f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000003a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a2f2f3a3a3a3a3a3a3a2f2f2f2f2f2f2f2f2f2f2f2f2f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000003a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a2f2f2f3a3a3a3a3a3a3a2f2f2f2f2f2f2f2f2f2f2f2f2f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000003a3a3a3a3a3a3a3a3a3a3a3a3a303030303a3a3a3a3a3a2f2f2f2f2f3a3a3a3a3a3a3a2f2f2f2f2f2f2f2f2f2f2f2f2f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000003a3a3a3a3a3a3a3a3a3a3a303031313130303a3a3a2f2f2f2f2f2f2f3a3a3a3a3a3a3a3a2f2f2f2f2f2f2f2f2f2f2f2f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000003a3a3a3a3a3a3a3a3a3a30303031323231303a3a2f2f2f2f2f2f2f2f2f3a3a3a3a3a3a3a2f2f2f2f2f2f2f2f2f2f2f2f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000003a3a3a3a3a3a3a3a3a3a30303031313131303a3a2f2f2f2f2f2f2f2f2f2f3a3a3a3a3a3a3a2f2f2f2f2f2f2f2f2f2f2f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000003a3a3a3a3a3a3a3a3a3a3a30303031303a3a3a2f2f2f2f2f2f2f2f2f2f2f3a3a3a3a3a3a3a3a2f2f2f2f2f2f2f2f2f2f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000003a3a3a3a3a3a3a3a3a3a3a3a3a30303a3a3a3a3a2f2f2f2f2f2f3a2f2f2f3a3a3a3a3a3a3a3a3a2f2f2f2f2f2f2f2f2f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000003a3a3a3a3a3a3a3a3a3a3a3a3a3a303a3a3a3a3a2f2f2f2f2f2f2f2f2f2f3a3a3a3a3a3a3a3a3a2f2f2f2f2f2f2f2f2f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000003a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a2f2f2f2f2f2f2f2f2f3a3a3a3a3a3a3a3a3a2f2f2f2f2f2f2f2f2f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000003a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a2f2f2f2f2f2f2f2f2f3a3a3a3a3a3a3a3a3a2f2f2f2f3a3a2f2f2f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000003a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a2f2f2f2f2f2f2f2f3a3a3a3a3a3a3a3a3a2f2f2f2f3a3a3a2f2f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000003a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a2f2f2f2f2f2f2f2f3a3a3a3a3a3a3a3a3a2f2f2f2f3a3a3a2f2f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000003a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a2f2f2f3a3a3a2f2f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000003a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a2f2f2f2f2f2f2f2f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000003a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a2f2f2f2f2f2f2f2f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000003a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a2f2f2f2f2f2f2f2f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000b00021023010230100501005010050100501005010050100501075013750137501805018050130501005010050100501005013050130500570005700057000570004700047000370002700027000270001700
00060000223301c3300a2000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100040a1400c140226101d61020600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000600002f6503367031670256701c67019660156600a650046400162003610016000361002600026000360001600016000160001600016000260002600026000360003600036000000000000000000000000000
000400001d5501d5501d5501c5501a550185501555013550105500955005550015500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00020000090500a7500a050097500504002740010300372001010067000870006000077000670007700087000800006700077000670007000097000670005700070000770019000180001800019000097001a000
000205201506018760180601776013060045400375003550055500575004550055400554005540055400374005530065400554005540055400455005540067400455005550057500455004550045500575004540
000300200161002610026100261001610016100161002610026100261003610036100361003610036100361004610046100461003610036100361003610036100361003610036100361003610026100261002610
000300002b460146602b470156702a4701467026470126702247012660174500c64011430094200461003610016100261001650127001270010700057000e7000c700097000870006700067001a0000000000000
000b00002d550255502d550255401e53018540135500d540095200652003530015500155014400103000f30015400123001430017300163000f30010300133001330010300103001030011300123001230012300
