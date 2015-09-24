Library "v30/bslDefender.brs"
Sub Main()
	' ***Start Section - Initialize Global Variables***
	deviceInfo = CreateObject("roDeviceInfo")
	display_type = deviceInfo.GetDisplayType()
	If display_type = "HDTV" or display_type = "16:9 anamorphic"
		m.screen = CreateObject("roScreen",True,854,480)
		m.drawRegions = dfSetupDisplayRegions(m.screen,0,0,854,480)
	Else
		m.screen = CreateObject("roScreen",True,854,626)
		m.drawRegions = dfSetupDisplayRegions(m.screen,0,73,854,480)
	End If
	m.drawMain = m.drawRegions.Main
	m.port = CreateObject("roMessagePort")
	m.screen.SetAlphaEnable(True)
	m.drawMain.SetAlphaEnable(True)
	m.screen.SetMessagePort(m.port)
	m.compositor = CreateObject("roCompositor")
	m.compositor.SetDrawTo(m.drawMain, 0)

	' Substitute for Pi since Pi is not available in brightscript
	m.pi = 3.14159265358979323846264338327950

	' ***End Section - Initialize Global Variables***

	' Create the circle bitmap
	bm_circle = CreateObject("roBitmap", "pkg:/sprites/circle.png")

	' Create array to hold scaled bitmaps
	bm_circle_array = []

	' Create array to hold sprites
	spr_circle = []

	For a = 0 To 19

		' Set a random scale for the circle, also acts as the circle's mass
		circle_scale = (rnd(10))/10

		' Push the new bitmap to an array
		bm_circle_array.Push(CreateObject("roBitmap", {width:100, height:100, AlphaEnable:True}))
		bm_circle_array[a].DrawScaledObject(0, 0, circle_scale, circle_scale, bm_circle)

		' Create a region with appropriate collision circle from the newly created bitmap
		region_circle = CreateObject("roRegion", bm_circle_array[a], 0, 0, 100 * circle_scale, 100 * circle_scale)
		region_circle.SetCollisionCircle((100 * circle_scale)/2, (100 * circle_scale)/2, (100 * circle_scale)/2)
		region_circle.SetCollisionType(2)

		' Push the new region into a sprite in the array of circle sprites.
		spr_circle.Push(m.compositor.NewSprite(rnd(854-106), rnd(480-106), region_circle, 1))
		spr_circle[a].SetData({xspeed: rnd(11)-6, yspeed: rnd(11)-6, xpos: spr_circle[a].GetX(), ypos: spr_circle[a].GetY(), mass: 100 * circle_scale, size: 100 * circle_scale, collided: False, collided_with: [], id: a})

		' Check if the circle is being spawned on top of another circle, if so spawn somewhere else.
		check_initial_collision:
		If spr_circle[a].CheckCollision() <> Invalid
			newX = rnd(854-106)
			newY = rnd(480-106)
			data = spr_circle[a].GetData()
			spr_circle[a].MoveTo(newX, newY)
			data.xpos = newX
			data.ypos = newY
			spr_circle[a].SetData(data)
			goto check_initial_collision
		End If
	End For


	While True

		'Draw Background
		m.drawMain.DrawRect(0, 0, 854, 480, &h000000FF)

		' ***** Start - Handle Sprite Behavior*****
		For a = 0 to spr_circle.Count()-1

			' Set up temporary variables for this sprite
			sprite = spr_circle[a]
			data = sprite.GetData()

			' Set new positions based on speed
			data.xpos = data.xpos + data.xspeed
			data.ypos = data.ypos + data.yspeed

			' Move the sprite
			sprite.MoveTo(data.xpos, data.ypos)

			' Check if the sprite is colliding with any other sprites
			collided_sprite = sprite.CheckCollision()

			' If the sprite previously collided, check if it is no longer colliding. If not, set colliding to false.
			If data.collided
				If collided_sprite = Invalid
					data.collided = False
					data.collided_with = []
				End If
			End If

			' Detect collision with wall, use Abs() so the sprite doesn't get lost beyond the wall in infinite reversal of direction
			If sprite.GetX() < 0 
				data.xspeed = Abs(data.xspeed)
			End If
			If sprite.GetX() > 854 - data.size
				data.xspeed = Abs(data.xspeed) * -1
			End If
			If sprite.GetY() < 0
				data.yspeed = Abs(data.yspeed)
			End If
			If sprite.GetY() > 480 - data.size
				data.yspeed = Abs(data.yspeed) * -1
			End If

			sprite.SetData(data)

			' If the sprite wasn't already colliding, check to see if there is a collision and handle the collision with ManageBounce()
			If collided_sprite <> Invalid

				' If the sprite is not already colliding with anything, handle the bounce.
				If not data.collided
					new_data = ManageBounce(sprite, collided_sprite)
					sprite.SetData(new_data.data_1)
					collided_sprite.SetData(new_data.data_2)
				' If the sprite is already in a collision, check to see if this is a collision with a new sprite that is not already part of the collision. 
				Else
					already_in_collision = False
					For Each collided_id in data.collided_with
						If collided_id = collided_sprite.GetData().id
							already_in_collision = True
							Exit For													
						End If
					End For
					If not already_in_collision
						new_data = ManageBounce(sprite, collided_sprite)
						sprite.SetData(new_data.data_1)
						collided_sprite.SetData(new_data.data_2)
						print "Multi Collision = " ; data.collided_with.Count()
					End If
				End If
			End If 


		End For
		' ***** End - Handle Sprite Behavior*****

		m.compositor.DrawAll()
		m.screen.SwapBuffers()
	End While
End Sub

Function ManageBounce(ball_1, ball_2)

	' Credits for this ManageBounce() function go to - http://www.emanueleferonato.com/2007/08/19/managing-ball-vs-ball-collision-with-flash/
	
	' Get the data from each sprite
	data_1 = ball_1.GetData()
	data_2 = ball_2.GetData()

	' Get the x and y distances between the balls.
	dx = (ball_1.GetX()+(data_1.size/2)) - (ball_2.GetX()+(data_2.size/2))
	dy = (ball_1.GetY()+(data_1.size/2)) - (ball_2.GetY()+(data_2.size/2))

	' Get collision angle using atan2 simulation. 
	If dx > 0
		collision_angle = Atn(dy/dx)
	Else If dy >= 0 and dx < 0
		collision_angle = Atn(dy/dx)+m.pi
	Else If dy < 0 and dx < 0
		collision_angle = Atn(dy/dx)-m.pi
	Else If dy > 0 and dx = 0
		collision_angle = m.pi/2
	Else If dy < 0 and dx = 0
		collision_angle = (m.pi/2)*-1
	Else
		collision_angle = 0
	End If

	' *** Uncomment this if you want to view the collision angle in degrees***
	' If collision_angle*57.29578 < 0
	' 	print "collision_angle = " ; collision_angle*57.29578+360
	' Else
	' 	print "collision_angle = " ; collision_angle*57.29578
	' End If

	' Get magnitude using pythagorean theorem
	magnitude_1 = Sqr((data_1.yspeed*data_1.yspeed)+(data_1.xspeed*data_1.xspeed))
	magnitude_2 = Sqr((data_2.yspeed*data_2.yspeed)+(data_2.xspeed*data_2.xspeed))


	' Get direction of ball 1 using atan2 simulation
	If data_1.xspeed > 0
		direction_1 = Atn(data_1.yspeed/data_1.xspeed)
	Else If data_1.yspeed >= 0 and data_1.xspeed < 0
		direction_1 = Atn(data_1.yspeed/data_1.xspeed)+m.pi
	Else If data_1.yspeed < 0 and data_1.xspeed < 0
		direction_1 = Atn(data_1.yspeed/data_1.xspeed)-m.pi
	Else If data_1.yspeed > 0 and data_1.xspeed = 0
		direction_1 = m.pi/2
	Else If data_1.yspeed < 0 and data_1.xspeed = 0
		direction_1 = (m.pi/2)*-1
	Else
		direction_1 = 0
	End If

	' Get direction of ball 2 using atan2 simulation
	If data_2.xspeed > 0
		direction_2 = Atn(data_2.yspeed/data_2.xspeed)
	Else If data_2.yspeed >= 0 and data_2.xspeed < 0
		direction_2 = Atn(data_2.yspeed/data_2.xspeed)+m.pi
	Else If data_2.yspeed < 0 and data_2.xspeed < 0
		direction_2 = Atn(data_2.yspeed/data_2.xspeed)-m.pi
	Else If data_2.yspeed > 0 and data_2.xspeed = 0
		direction_2 = m.pi/2
	Else If data_2.yspeed < 0 and data_2.xspeed = 0
		direction_2 = (m.pi/2)*-1
	Else
		direction_2 = 0
	End If

	' Solve for new velocities (other sides of triangle) using trigonometry 
	new_xspeed_1 = magnitude_1*cos(direction_1-collision_angle)
	new_yspeed_1 = magnitude_1*sin(direction_1-collision_angle)
	new_xspeed_2 = magnitude_2*cos(direction_2-collision_angle)
	new_yspeed_2 = magnitude_2*sin(direction_2-collision_angle)

	' Factor in masses to new velocities
	final_xspeed_1 = ((data_1.mass-data_2.mass)*new_xspeed_1+(data_2.mass+data_2.mass)*new_xspeed_2)/(data_1.mass+data_2.mass)
	final_xspeed_2 = ((data_1.mass+data_1.mass)*new_xspeed_1+(data_2.mass-data_1.mass)*new_xspeed_2)/(data_1.mass+data_2.mass)
	final_yspeed_1 = new_yspeed_1
	final_yspeed_2 = new_yspeed_2

	' Do some magic
	data_1.xspeed = cos(collision_angle)*final_xspeed_1+cos(collision_angle+m.pi/2)*final_yspeed_1
	data_1.yspeed = sin(collision_angle)*final_xspeed_1+sin(collision_angle+m.pi/2)*final_yspeed_1
	data_2.xspeed = cos(collision_angle)*final_xspeed_2+cos(collision_angle+m.pi/2)*final_yspeed_2
	data_2.yspeed = sin(collision_angle)*final_xspeed_2+sin(collision_angle+m.pi/2)*final_yspeed_2

	' Set the sprite as having had a collision and with which sprite it had a collision
	data_1.collided = True
	data_1.collided_with.Push(data_2.id)
	data_2.collided = True
	data_2.collided_with.Push(data_1.id)

	' Place in associative array for return
	new_data = {data_1: data_1, data_2: data_2}
 
	return new_data

End Function