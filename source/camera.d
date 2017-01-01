import matrix4x4;
import vec3;

public class Camera
{
    public void setProjection( float fovDegrees, float aspect, float near, float far )
    {
        this.fovDegrees = fovDegrees;
        this.aspect = aspect;
        this.near = near;
        this.far = far;

        projectionMatrix.makeProjection( fovDegrees, aspect, near, far );
        viewMatrix.makeIdentity();
    }

    public void lookAt( Vec3 eyePosition, Vec3 center )
    {
        viewMatrix.makeLookAt( eyePosition, center, Vec3( 0, 1, 0 ) );
    }

    public Matrix4x4 getProjection() const
    {
        return projectionMatrix;
    }

    public Matrix4x4 getView() const
    {
        return viewMatrix;
    }

    private float fovDegrees = 45;
    private float aspect = 16.0f / 9.0f;
    private float near = 1;
    private float far = 300;
    private Matrix4x4 viewMatrix;
    private Matrix4x4 projectionMatrix;
}
