extends Area2D


export var lifeTime : int
var type : String
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	pass

func _draw():
	if type == 'RETURN':
		draw_circle(Vector2(), 5, Color(0, 0, 1, 1))
	else:
		draw_circle(Vector2(), 5, Color(1, 0, 0, 1))
	
func _process(delta):
	self.modulate -= Color(0, 0, 0, delta / lifeTime)


func _on_Timer_timeout():
	get_parent().remove_child(self)
