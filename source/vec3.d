import std.math: abs, sqrt, approxEqual;

public Vec3 Cross( Vec3 v1, Vec3 v2 )
{
    return Vec3( v1.y * v2.z - v1.z * v2.y,
                 v1.z * v2.x - v1.x * v2.z,
                 v1.x * v2.y - v1.y * v2.x );
}

public float Dot( Vec3 v1, Vec3 v2 )
{
    return v1.x * v2.x + v1.y * v2.y + v1.z * v2.z; 
}

public void Normalize( ref Vec3 v )
{
    const float len = Length( v );
    //assert( approxEqual( len, 0.0f ), "length is 0" );
    v.x /= len;
    v.y /= len;
    v.z /= len;
}

public float Length( ref Vec3 v )
{
    return sqrt( v.x * v.x + v.y * v.y + v.z * v.z );
}

private bool IsAlmost( Vec3 v1, Vec3 v2 )
{
    return approxEqual( v1.x, v2.x ) && approxEqual( v1.y, v2.y ) && approxEqual( v1.z, v2.z );
}

struct Vec3
{
    this( float ax, float ay, float az )
    {
        x = ax;
        y = ay;
        z = az;
    }

    Vec3 opBinary( string op )( Vec3 v ) const
    {
        static if (op == "+")
        {
            return Vec3( x + v.x, y + v.y, z + v.z );
        }
        else static if (op == "-")
        {
            return Vec3( x - v.x, y - v.y, z - v.z );
        }
        else static assert( false, "operator " ~ op ~ " not implemented" );
    }

    Vec3 opBinary( string op )( float f ) const
    {
        static if (op == "*")
        {
            return Vec3( x * f, y * f, z * f );
        }
        else static assert( false, "operator " ~ op ~ " not implemented" );
    }

    float x = 0, y = 0, z = 0;
}

unittest
{
    Vec3 v = Vec3( 6, 6, 6 );
    Normalize( v );
    assert( approxEqual( Length( v ), 1 ), "Vec3 Length failed" );

    assert( IsAlmost( Cross( Vec3( 1, 0, 0 ), Vec3( 0, 1, 0 ) ), Vec3( 0, 0, 1 ) ), "Vec3 Cross failed" );
}
