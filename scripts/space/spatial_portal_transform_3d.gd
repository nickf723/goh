extends RefCounted
class_name SpatialPortalTransform3D


static func mapping_between(
	source_transform: Transform3D,
	destination_transform: Transform3D
) -> Transform3D:
	var source: Transform3D = source_transform.orthonormalized()
	var destination: Transform3D = destination_transform.orthonormalized()
	var half_turn: Transform3D = Transform3D(
		Basis(Vector3.UP, PI),
		Vector3.ZERO
	)
	return destination * half_turn * source.affine_inverse()


static func map_transform(
	source_transform: Transform3D,
	destination_transform: Transform3D,
	traveler_transform: Transform3D
) -> Transform3D:
	return (
		mapping_between(source_transform, destination_transform)
		* traveler_transform.orthonormalized()
	)


static func map_vector(
	source_transform: Transform3D,
	destination_transform: Transform3D,
	vector: Vector3
) -> Vector3:
	return mapping_between(source_transform, destination_transform).basis * vector

