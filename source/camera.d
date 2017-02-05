import matrix4x4;
import std.math: approxEqual;
import quaternion;
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
        Matrix4x4 lookAt;
        lookAt.makeLookAt( eyePosition, center, Vec3( 0, 1, 0 ) );
        rotation.fromMatrix( lookAt );
        position = eyePosition;

        viewMatrix.makeLookAt( eyePosition, center, Vec3( 0, 1, 0 ) );
    }

    public void moveRight( float amount )
    {
        if (!approxEqual( amount, 0 ))
        {
            position = position + rotation * Vec3( amount, 0, 0 );
        }
    }

    public void moveUp( float amount )
    {
        position.y += amount;
    }

    public void moveForward( float amount )
    {
        if (!approxEqual( amount, 0 ))
        {
            position = position + rotation * Vec3( 0, 0, amount );
        }
    }

    public void offsetRotate( Vec3 axis, float angleDegrees )
    {
        Quaternion rot;
        rot.fromAxisAngle( axis, angleDegrees );

        Quaternion newRotation;

        if (approxEqual( axis.y, 0 ))
        {
            newRotation = rotation * rot;
        }
        else
        {
            newRotation = rot * rotation;
        }

        newRotation.normalize();

        /*Vec3 vx = Vec3( 1.0f, 0.0f, 0.0f );

        if ((approxEqual( axis.x, 1 ) || approxEqual( axis.x, -1 )) && approxEqual( axis.y, 0 ) && approxEqual( axis.z, 0 ) &&
            newRotation.findTwist( vx ) > 0.9999f)
        {
            return;
        }*/

        rotation = newRotation;
    }

    public void updateMatrix()
    {
        viewMatrix.makeIdentity();
        viewMatrix.translate( position );

        Matrix4x4 rotMatrix;
        rotation.getMatrix( rotMatrix );
        multiply( viewMatrix, rotMatrix, viewMatrix );
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
    Vec3 position;
    Quaternion rotation;
}
