extends KinematicBody2D

#Parameters
export var speed : int
export var sideRaysLength : int
export var sideRaysAngle : int
export var angleMaxRateChange : float

#Internal variables
var velocity : Vector2 = Vector2.UP.rotated(-rotation)
var newVelocity : Vector2
var newRotation : float
var screenSize
var rayColor = Color(1, 0, 0, 1)
var taskType : String = 'SEARCH'
var target = null
var carriedResource : KinematicBody2D = null
#var visitedPheromones = []
var rng = RandomNumberGenerator.new()

#Constants
const PheromoneScene = preload("res://Pheromone.tscn")
const ResourceScene : PackedScene = preload('res://Resource.tscn')

func _ready():
	screenSize = get_viewport_rect().size
	rng.randomize()
	
func start(pos):
	position = pos
	show()
	$CollisionShape2D.disabled = false
	$RayCast2D_L.rotation = -deg2rad(sideRaysAngle)
	$RayCast2D_R.rotation = deg2rad(sideRaysAngle)
	$RayCast2D_L.cast_to = Vector2(0, -sideRaysLength)
	$RayCast2D_R.cast_to = Vector2(0, -sideRaysLength)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	update()
#	lookForPheromones()
#	if target != null and position.distance_to(target.position) < 10:
#		target = null
#	if target == null:
	newVelocity = avoidObstacles()
	velocity = lerp(velocity, newVelocity, 0.1).normalized()
	rotation = lerp_angle(rotation, -velocity.angle_to(Vector2.UP), 0.3)
	
	var collision : KinematicCollision2D = move_and_collide(velocity * delta * speed)
	if collision != null and collision.get_collider().get_name() == 'Resource':
		print(collision.get_collider().get_name())
		pickUpResource(collision.get_collider())
	if carriedResource != null:
		carriedResource.position = position
		carriedResource.rotation = rotation

		
func pickUpResource(resource : KinematicBody2D):
	target = null
	taskType = 'RETURN'
	carriedResource = resource
	resource.get_node('CollisionShape2D').disabled = true
	resource.scale = Vector2(1.2, 1.2)
	
	

func lookForPheromones():
	var pheromonesInFOV = $FieldOfView.get_overlapping_areas()
	#Check type of pheromones in FOV
	for pheromone in pheromonesInFOV:
		if pheromone.type != taskType:
			pheromonesInFOV.erase(pheromone)
	#Cast rays to pheromones in FOV
	for pheromone in pheromonesInFOV:
		var space_state = get_world_2d().direct_space_state
		var result = space_state.intersect_ray(position, pheromone.position, [self], 2)
		print(result.size())
		if not result.empty():
			pheromonesInFOV.erase(pheromone)
	#Find furthes one
	var maximumDistance : float = -1
	for pheromone in pheromonesInFOV:
		if position.distance_to(pheromone.position) >= maximumDistance:
			maximumDistance = position.distance_to(pheromone.position)
	#Face on closest
	for pheromone in pheromonesInFOV:
		if position.distance_to(pheromone.position) == maximumDistance:
			var angle = velocity.angle_to(pheromone.position - position)
			velocity = velocity.rotated(angle)
			pheromone.modulate += Color(1, 0, -1, 0)
			break
			
func avoidObstacles():
	var v : Vector2 = velocity.normalized() * sideRaysLength * 1.3
	if $RayCast2D_L.is_colliding():
		var lp = $RayCast2D_L.get_collision_point()
		var danger = sideRaysLength - position.distance_to(lp)
		var leftCorrection = Vector2.DOWN.rotated(rotation - deg2rad(sideRaysAngle)) * danger
		v += leftCorrection
#		print('Left impulse: ', rad2deg(leftCorrection.angle_to(Vector2.UP)))
	if $RayCast2D_R.is_colliding():
		var rp = $RayCast2D_R.get_collision_point()
		var danger = sideRaysLength - position.distance_to(rp)
		var rightCorrection = Vector2.DOWN.rotated(rotation + deg2rad(sideRaysAngle)) * danger
		v += rightCorrection
#		print('Right impulse: ', rad2deg(rightCorrection.angle_to(Vector2.UP)))
		
	return v.normalized()
	
func rateLimiter(v : Vector2, newV : Vector2, rate : float):
	var angle = v.angle_to(newV)
	if -rate <= angle and angle <= rate:
		velocity = v.rotated(angle)
	elif angle < -deg2rad(175) or angle > deg2rad(175):
		var rndAngle = rng.randf_range(-15.0, 15.0)
		velocity = v.rotated(angle + deg2rad(rndAngle))
	elif angle < -rate:
		velocity =  v.rotated(-rate)
	else:
		velocity = v.rotated(rate)
	

func _draw():
	var lp = $RayCast2D_L.get_collision_point()
	var rp = $RayCast2D_R.get_collision_point()
	
	if $RayCast2D_L.is_colliding():
		draw_circle((lp - position).rotated(-rotation), 5, rayColor)
		draw_line(Vector2(), (lp - position).rotated(-rotation), rayColor, 1, true)
	else:
		draw_line(Vector2(), Vector2(0, -sideRaysLength).rotated(deg2rad(-sideRaysAngle)), rayColor, 1, true)
		
	if $RayCast2D_R.is_colliding():
		draw_circle((rp - position).rotated(-rotation), 5, rayColor)
		draw_line(Vector2(), (rp - position).rotated(-rotation), rayColor, 1, true)
	else:
		draw_line(Vector2(), Vector2(0, -sideRaysLength).rotated(deg2rad(sideRaysAngle)), rayColor, 1, true)
	

func _on_DirectionRefreshRate_timeout():
#	if target == null:
#		newVelocity = avoidObstacles()
	$DirectionRefreshRate.start()


func _on_PheromoneSpawnRate_timeout():
	var pheromone = PheromoneScene.instance()
	
	pheromone.position = position
	if taskType == 'SEARCH':
		pheromone.type = 'RETURN'
	else:
		pheromone.type = 'SEARCH'
	
	get_parent().add_child(pheromone)

# Spotting resource
func _on_FieldOfView_body_entered(body):
	if body.get_collision_layer() == 4 and (target == null or target.name != 'Resource'):
		var space_state = get_world_2d().direct_space_state
		var resource = body
		var result = space_state.intersect_ray(position, resource.position, [self], 1)
		if result.empty():
			target = resource
			var angle = velocity.angle_to(resource.position - position)
			newVelocity = velocity.rotated(angle)
			print('locked')	


func _on_FieldOfView_area_entered(area):
	if area.get_collision_layer() == 2 and (target == null or target.name == 'Pheromone'):
		var pheromone = area
		if target == null:
			target = pheromone
		if position.distance_to(target.position) <= position.distance_to(pheromone.position):
			target = pheromone
			var angle = velocity.angle_to(pheromone.position - position)
			newVelocity = velocity.rotated(angle)
