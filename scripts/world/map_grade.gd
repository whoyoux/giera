class_name MapGrade
extends RefCounted
## Wspolny wyglad swiata na wszystkich mapach: filmowy tonemapper, mniejsze nasycenie i stonowane
## niebo, mgla oraz swiatlo. Sceny map trzymaja swoje kolory (pora dnia, klimat), a ta warstwa
## sciaga je do jednej, doroslejszej palety, zamiast przerabiac kazda scene osobno.

## ACES daje mocniejszy kontrast niz Filmic i sam przygasza przesycone kolory w jasnych miejscach.
const TONEMAPPER := Environment.TONE_MAPPER_ACES
const EXPOSURE := 0.9
const SATURATION := 0.97
const CONTRAST := 1.1
## Rzadsza mgla: daleki plan nie zlewa sie w mleko.
const FOG_SCALE := 0.7
## Ile koloru zabrac (0 nic, 1 szarosc).
const SKY_DESATURATE := 0.12
const FOG_DESATURATE := 0.25
const AMBIENT_DESATURATE := 0.35
const SUN_DESATURATE := 0.1
## Ciemniejsze cienie: mniej swiatla otoczenia.
const AMBIENT_SCALE := 0.9
const GLOW_SCALE := 0.6
## Ostre poludniowe slonce przepala jasne mapy, wiec jego moc ma gorny limit.
const SUN_MAX_ENERGY := 1.05


## Wolac dla kazdej nowo wczytanej mapy. Slonce to nowy wezel przy kazdym wczytaniu, wiec jest
## zmieniane zawsze, a srodowisko to zasob wspolny dla kolejnych wczytan, wiec tylko raz.
static func apply(world: Node) -> void:
	var sun := world.get_node_or_null("Sun") as DirectionalLight3D
	if sun != null:
		sun.light_color = desaturate(sun.light_color, SUN_DESATURATE)
		sun.light_energy = minf(sun.light_energy, SUN_MAX_ENERGY)
	var holder := world.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if holder != null and holder.environment != null and not holder.environment.has_meta(&"graded"):
		_grade_environment(holder.environment)


static func _grade_environment(environment: Environment) -> void:
	environment.set_meta(&"graded", true)
	environment.tonemap_mode = TONEMAPPER
	environment.tonemap_exposure = EXPOSURE
	environment.adjustment_enabled = true
	environment.adjustment_saturation = SATURATION
	environment.adjustment_contrast = CONTRAST
	environment.ambient_light_color = desaturate(environment.ambient_light_color, AMBIENT_DESATURATE)
	environment.ambient_light_energy *= AMBIENT_SCALE
	environment.fog_light_color = desaturate(environment.fog_light_color, FOG_DESATURATE)
	environment.fog_density *= FOG_SCALE
	environment.glow_intensity *= GLOW_SCALE
	var sky := environment.sky.sky_material as ProceduralSkyMaterial if environment.sky != null else null
	if sky != null:
		sky.sky_top_color = desaturate(sky.sky_top_color, SKY_DESATURATE)
		sky.sky_horizon_color = desaturate(sky.sky_horizon_color, SKY_DESATURATE)
		sky.ground_horizon_color = desaturate(sky.ground_horizon_color, SKY_DESATURATE)
		sky.ground_bottom_color = desaturate(sky.ground_bottom_color, SKY_DESATURATE)


static func desaturate(color: Color, amount: float) -> Color:
	var gray := color.get_luminance()
	return color.lerp(Color(gray, gray, gray, color.a), amount)
